//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import CoreBluetooth
import NIOCore
import Observation
import OSLog


private enum AccessorContinuation {
    case read(_ continuation: [CheckedContinuation<Data, Error>])
    case write(_ continuation: CheckedContinuation<Data, Error>)
}


/// A dedicated state container for a ``BluetoothPeripheral``.
///
/// Main motivation is to have `BluetoothPeripheral` be implemented as an actor and moving state
/// into a separate state container that is `@Observable`.
@Observable
private final class BluetoothPeripheralState { // TODO: move out (all of them)?
    var name: String?
    var rssi: Int
    var advertisementData: AdvertisementData
    var state: PeripheralState
    var lastActivity: Date

    var services: [CBService]? // swiftlint:disable:this discouraged_optional_collection

    /// The list of requested characteristic uuids indexed by service uuids.
    var requestedCharacteristics: [CBUUID: [CBUUID]]? // swiftlint:disable:this discouraged_optional_collection

    init(name: String?, rssi: Int, advertisementData: AdvertisementData, state: CBPeripheralState, lastActivity: Date = .now) {
        self.name = name
        self.advertisementData = advertisementData
        self.rssi = rssi
        self.state = .init(from: state)
        self.lastActivity = lastActivity
    }
}


private struct CharacteristicLocator: Hashable {
    let serviceId: CBUUID
    let characteristicId: CBUUID
}


/// An active registration of a notification handler.
///
/// This object represents an active registration of an notification handler. Primarily, this can be used to keep
/// track of a notification handler and cancel the registration at a later point.
///
/// - Tip: The notification handler will be automatically unregistered when this object is deallocated.
public class CharacteristicNotification { // TODO: move to Model vs Utilities?
    private weak var peripheral: BluetoothPeripheral?
    fileprivate let locator: CharacteristicLocator
    let handlerId: UUID


    fileprivate init(peripheral: BluetoothPeripheral?, locator: CharacteristicLocator, handlerId: UUID) {
        self.peripheral = peripheral
        self.locator = locator
        self.handlerId = handlerId
    }


    /// Cancel the notification handler registration.
    public func cancel() async {
        await peripheral?.deregisterNotification(self)
    }


    deinit {
        // make sure we don't capture self after this deinit
        let peripheral = peripheral
        let locator = locator
        let handlerId = handlerId

        Task {
            await peripheral?.deregisterNotification(locator: locator, handlerId: handlerId)
        }
    }
}


/// A nearby Bluetooth peripheral.
///
/// ## Topics
///
/// ### Device State
/// - ``id``
/// - ``name``
/// - ``state``
/// - ``rssi``
/// - ``advertisementData``
/// - ``services``
///
/// ### Managing Connection
/// - ``connect()``
/// - ``disconnect()``
///
/// ### Device Interactions
/// - ``read(characteristic:)``
/// - ``write(data:for:)``
/// - ``writeWithoutResponse(data:for:)``
/// - ``registerNotifications(for:_:)``
/// - ``readRSSI()``
public actor BluetoothPeripheral: Identifiable, KVOReceiver {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothDevice")

    private weak var manager: BluetoothManager?
    private let peripheral: CBPeripheral

    private let delegate: Delegate
    private let stateObserver: KVOStateObserver<BluetoothPeripheral>

    /// Ongoing accessed indexed by characteristic uuid.
    private var ongoingAccesses: [CBCharacteristic: AccessorContinuation] = [:]
    /// Continuation for the current write without response access.
    private var writeWithoutResponseAccess: [CheckedContinuation<Void, Never>] = []
    /// Continuation for a currently ongoing rssi read access.
    private var rssiReadAccess: [CheckedContinuation<Int, Error>] = []

    private var notificationHandlers: [CharacteristicLocator: [UUID: BluetoothNotificationHandler]] = [:]

    /// Observable state container for local state.
    private let stateContainer: BluetoothPeripheralState

    nonisolated var cbPeripheral: CBPeripheral {
        peripheral
    }

    /// The internally managed identifier for the peripheral.
    public nonisolated var id: UUID {
        peripheral.identifier
    }

    /// The name of the peripheral.
    public nonisolated var name: String? {
        stateContainer.name
    }

    /// The current signal strength.
    public nonisolated var rssi: Int {
        stateContainer.rssi
    }

    /// The advertisement data of the last bluetooth advertisement.
    public nonisolated var advertisementData: AdvertisementData {
        stateContainer.advertisementData
    }

    /// The current peripheral device state.
    public nonisolated var state: PeripheralState {
        stateContainer.state
    }

    /// The list of discovered services.
    ///
    /// Services are discovered automatically upon connection
    public nonisolated var services: [CBService]? { // swiftlint:disable:this discouraged_optional_collection
        stateContainer.services // TODO: Observable wrappers???
    }

    nonisolated var lastActivity: Date {
        if case .disconnected = state {
            stateContainer.lastActivity
        } else {
            // we are currently connected or connecting/disconnecting, therefore last activity is defined as "now"
            .now
        }
    }


    init(manager: BluetoothManager, peripheral: CBPeripheral, advertisementData: AdvertisementData, rssi: Int) {
        self.manager = manager
        self.peripheral = peripheral

        self.stateContainer = BluetoothPeripheralState(
            name: peripheral.name,
            rssi: rssi,
            advertisementData: advertisementData,
            state: peripheral.state
        )

        let delegate = Delegate()
        let observer = KVOStateObserver<BluetoothPeripheral>(entity: peripheral, property: \.state)

        self.delegate = delegate
        self.stateObserver = observer

        // we have this separate initDevice methods as otherwise above access to `delegate` and `stateObserver` properties
        // would become non-isolated accesses (due to usage of self beforehand).
        delegate.initDevice(self)
        observer.initReceiver(self)

        peripheral.delegate = delegate
    }

    /// Establish a connection to the peripheral.
    ///
    /// Make a connection to the peripheral.
    ///
    /// - Note: You might want to verify via the ``AdvertisementData/isConnectable`` property that the device is connectable.
    public func connect() async {
        // TODO: make it async till it connects??
        guard let manager else {
            logger.warning("Tried to connect an orphaned bluetooth peripheral!")
            return
        }

        await manager.connect(peripheral: self)
    }

    /// Disconnect the ongoing connection to the peripheral.
    ///
    /// Cancels an active or pending connection to a peripheral.
    public func disconnect() {
        guard let manager else {
            logger.warning("Tried to disconnect an orphaned bluetooth peripheral!")
            return
        }

        removeAllNotifications()

        manager.disconnect(peripheral: self)
    }

    func handleConnect() {
        if let description = manager?.findDeviceDescription(for: advertisementData) {
            stateContainer.requestedCharacteristics = description.services.reduce(into: [:]) { result, configuration in
                result[configuration.serviceId, default: []].append(contentsOf: configuration.characteristics)
            }
        } else {
            // all services will be discovered
            stateContainer.requestedCharacteristics = nil
        }

        self.stateContainer.state = .init(from: peripheral.state) // ensure that it is updated instantly.

        logger.debug("Discovering services for \(self.peripheral.debugIdentifier) ...")
        peripheral.discoverServices(stateContainer.requestedCharacteristics.map { Array($0.keys) })
    }

    nonisolated func handleDisconnect(disconnectActivityInterval: TimeInterval = 0) {
        // TODO: will ongoing writes, reads, ... be cancelled??
        //   throw ongoing promises with .notConnected?
        self.stateContainer.state = .init(from: peripheral.state) // ensure that it is updated instantly.

        self.stateContainer.lastActivity = Date.now - disconnectActivityInterval
    }

    nonisolated func update(advertisement: AdvertisementData, rssi: Int) {
        self.stateContainer.lastActivity = .now // fine to be non-isolated. We always just write the latest data

        // this could be a problem to be non-isolated, however, we know this will always come from the Bluetooth queue that is serial.
        stateContainer.advertisementData = advertisement
        stateContainer.rssi = rssi
    }

    /// Determines if the device is considered stale.
    ///
    /// This is the case if the device is not connected and the last activity is longer in the past than
    /// the provided interval.
    /// - Parameter interval: The time interval after which the device is considered stale.
    /// - Returns: True if the device is considered stale given the above criteria.
    nonisolated func isConsideredStale(interval: TimeInterval) -> Bool {
        state == .disconnected && lastActivity.addingTimeInterval(interval) < .now
    }

    nonisolated func matches(criteria: DiscoveryCriteria) -> Bool {
        switch criteria {
        case let .primaryService(uuid):
            return advertisementData.serviceUUIDs?.contains(uuid) ?? false
        }
    }

    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) async {
        switch keyPath {
        case \CBPeripheral.state:
            self.stateContainer.state = .init(from: value as! CBPeripheralState)
        default:
            break
        }
    }

    /// Register a notification handler for a characteristic.
    ///
    /// This method registers a notification handler for the provided characteristic.
    ///
    /// - Note: Make sure that you don't create a retain cycle if the provided closure captures `self`.
    ///
    /// - Parameters:
    ///   - characteristic: The characteristic to register notifications for.
    ///   - handler: The notification handler.
    /// - @Returns: Returns the ``CharacteristicNotification`` that can be used to cancel and deregister the notification handler.
    public func registerNotifications(
        for characteristic: CBCharacteristic,
        _ handler: @escaping BluetoothNotificationHandler
    ) throws -> CharacteristicNotification {
        guard let service = characteristic.service else {
            throw BluetoothError.notConnected
        }

        return registerNotifications(service: service.uuid, characteristic: characteristic.uuid, handler)
    }

    /// Register a notification handler for a characteristic.
    ///
    /// This method registers a notification handler for the provide service and characteristic id.
    ///
    /// - Tip: It is not required that the device is connected. Notifications will be automatically enabled for the
    /// respective characteristic upon device discovery.
    ///
    /// - Note: Make sure that you don't create a retain cycle if the provided closure captures `self`.
    ///
    /// - Parameters:
    ///   - service: The service uuid.
    ///   - characteristic: The characteristic uuid.
    ///   - handler: The notification handler.
    /// - @Returns: Returns the ``CharacteristicNotification`` that can be used to cancel and deregister the notification handler.
    public func registerNotifications(
        service: CBUUID,
        characteristic: CBUUID,
        _ handler: @escaping BluetoothNotificationHandler
    ) -> CharacteristicNotification {
        let locator = CharacteristicLocator(serviceId: service, characteristicId: characteristic)
        let id = UUID() // notification handler id, used internally

        notificationHandlers[locator, default: [:]]
            .updateValue(handler, forKey: id)


        // if setting notify doesn't work here, we do it upon discovery of the characteristics
        trySettingNotifyValue(true, serviceId: service, characteristicId: characteristic)

        return CharacteristicNotification(peripheral: self, locator: locator, handlerId: id)
    }

    func deregisterNotification(_ notification: CharacteristicNotification) {
        deregisterNotification(locator: notification.locator, handlerId: notification.handlerId)
    }

    fileprivate func deregisterNotification(locator: CharacteristicLocator, handlerId: UUID) {
        notificationHandlers[locator]?.removeValue(forKey: handlerId)

        trySettingNotifyValue(false, serviceId: locator.serviceId, characteristicId: locator.characteristicId)
    }

    private func trySettingNotifyValue(_ notify: Bool, serviceId: CBUUID, characteristicId: CBUUID) {
        if let service = services?.first(where: { $0.uuid == serviceId }),
           let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicId }),
           characteristic.properties.contains(.notify) {
            peripheral.setNotifyValue(notify, for: characteristic)
        }
    }

    /// Call this when things either go wrong, or you're done with the connection.
    /// This cancels any subscriptions if there are any, or straight disconnects if not.
    /// (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
    private func removeAllNotifications() {
        guard case .connected = peripheral.state else {
            return
        }

        // we need to unsubscribe before we cancel the connection
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? []  where characteristic.isNotifying {
                peripheral.setNotifyValue(false, for: characteristic)
            }
        }
    }

    /// Write the value of a characteristic expecting a response.
    ///
    /// Writes the value of a characteristic expecting a confirmation from the peripheral.
    ///
    /// - Parameters:
    ///   - data: The value to write.
    ///   - characteristic: The characteristic to which the value is written.
    /// - Returns: The response from the device.
    /// - Throws: Throws an `CBError`, `CBATTError` or ``BluetoothError`` if the write fails.
    public func write(data: Data, for characteristic: CBCharacteristic) async throws -> Data {
        guard ongoingAccesses[characteristic] == nil else {
            throw BluetoothError.concurrentWriteCharacteristicAccess
        }

        // TODO: are we actually getting data back?
        return try await withCheckedThrowingContinuation { continuation in
            // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
            ongoingAccesses.updateValue(.write(continuation), forKey: characteristic)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    /// Write the value of a characteristic without expecting a response.
    ///
    /// Writes the value of a characteristic without expecting a confirmation from the peripheral.
    ///
    /// - Parameters:
    ///   - data: The value to write.
    ///   - characteristic: The characteristic to which the value is written.
    public func writeWithoutResponse(data: Data, for characteristic: CBCharacteristic) async {
        guard writeWithoutResponseAccess.isEmpty else {
            await withCheckedContinuation { continuation in
                writeWithoutResponseAccess.append(continuation)
            }
            return
        }

        await withCheckedContinuation { continuation in
            writeWithoutResponseAccess.append(continuation)
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }

    /// Read the value of a characteristic.
    ///
    /// Read the value for the specified characteristic.
    ///
    /// - Parameter characteristic: The characteristic for which you want to read the value.
    /// - Returns: The value that the peripheral was returned.
    /// - Throws: Throws an `CBError`, `CBATTError` or ``BluetoothError`` if the read fails.
    public func read(characteristic: CBCharacteristic) async throws -> Data {
        guard ongoingAccesses[characteristic] == nil else {
            if case var .read(continuations) = ongoingAccesses[characteristic] {
                return try await withCheckedThrowingContinuation { continuation in
                    continuations.append(continuation)
                    // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
                    ongoingAccesses.updateValue(.read(continuations), forKey: characteristic)
                }
            } else {
                throw BluetoothError.concurrentWriteCharacteristicAccess
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
            ongoingAccesses.updateValue(.read([continuation]), forKey: characteristic)
            peripheral.readValue(for: characteristic)
        }
    }

    /// Retrieve the current RSSI value.
    ///
    /// Retrieves the current RSSI value for the peripheral while its connected.
    /// - Returns: The read rssi value.
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    public func readRSSI() async throws -> Int {
        guard rssiReadAccess.isEmpty else {
            return try await withCheckedThrowingContinuation { continuation in
                rssiReadAccess.append(continuation)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            rssiReadAccess.append(continuation)
            peripheral.readRSSI()
        }
    }
}


// MARK: Delegate Accessors
extension BluetoothPeripheral {
    fileprivate func update(name: String?) {
        self.stateContainer.name = name
    }

    fileprivate func update(rssi: Int, error: Error?) {
        stateContainer.rssi = rssi

        let result: Result<Int, Error>
        if let error {
            result = .failure(error)
        } else {
            result = .success(rssi)
        }

        for continuation in rssiReadAccess {
            continuation.resume(with: result)
        }

        self.rssiReadAccess.removeAll()
    }

    fileprivate func discovered(characteristics: [CBCharacteristic], for service: CBService) {
        // automatically subscribe to discovered characteristics for which we have a handler subscribed!
        for characteristic in characteristics {
            guard characteristic.properties.contains(.notify) else {
                continue
            }

            let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)

            if notificationHandlers[locator] != nil {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    fileprivate func receivedReadyNotification() {
        for continuation in writeWithoutResponseAccess {
            continuation.resume()
        }
        writeWithoutResponseAccess.removeAll()
    }

    fileprivate func receivedUpdatedValue(for characteristic: CBCharacteristic, result: Result<Data, Error>) async {
        if case let .read(continuations) = ongoingAccesses[characteristic] {
            ongoingAccesses[characteristic] = nil
            
            if case let .failure(error) = result {
                logger.debug("Characteristic read for \(characteristic.debugIdentifier) returned with error: \(error)")
            }

            for continuation in continuations {
                continuation.resume(with: result)
            }
            // TODO: @Characteristic assumes that we are getting notified of everything!!
        } else {
            switch result {
            case let .success(data):
                guard let service = characteristic.service else {
                    break
                }

                let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)

                for handler in notificationHandlers[locator, default: [:]].values {
                    await handler(data)
                }
            case let .failure(error):
                logger.debug("Received unsolicited value update error for \(characteristic.debugIdentifier): \(error)")
            }
        }
    }

    fileprivate func receivedWriteResponse(for characteristic: CBCharacteristic, result: Result<Data, Error>) {
        guard case let .write(continuation) = ongoingAccesses[characteristic] else {
            logger.warning("Received write response for \(characteristic.debugIdentifier) without an ongoing access. Discarding write ...")
            return
        }

        ongoingAccesses[characteristic] = nil

        if case let .failure(error) = result {
            logger.debug("Characteristic write for \(characteristic.debugIdentifier) returned with error: \(error)")
        }

        continuation.resume(with: result)
    }
}


// MARK: Hashable
extension BluetoothPeripheral: Hashable {
    public static func == (lhs: BluetoothPeripheral, rhs: BluetoothPeripheral) -> Bool {
        lhs.peripheral == rhs.peripheral
    }


    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(peripheral)
    }
}


// MARK: Delegate
extension BluetoothPeripheral {
    private class Delegate: NSObject, CBPeripheralDelegate {
        private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothDeviceDelegate")

        private weak var device: BluetoothPeripheral! // swiftlint:disable:this implicitly_unwrapped_optional

        override init() {
            super.init()
        }


        func initDevice(_ device: BluetoothPeripheral) {
            self.device = device
        }

        func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
            Task {
                await device.update(name: peripheral.name)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
            Task {
                await device.update(rssi: RSSI.intValue, error: error)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            // this is called if ...
            // 1) The peripheral removes a service from its database.
            // 2) The peripheral adds a new service to its database.
            // 3) The peripheral adds back a previously-removed service, but at a different location in the database.

            // so a service we requested might be gone now. Or might just have changed location. So, discover them to check if they moved location?

            let serviceIds = invalidatedServices.map { $0.uuid }
            logger.debug("Services modified, invalidating \(serviceIds)")

            // update our local model
            device.stateContainer.services?.removeAll(where: { invalidatedServices.contains($0) })

            peripheral.discoverServices(serviceIds)
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if let error {
                logger.error("Error discovering services: \(error.localizedDescription)")
                return
            }

            guard let services = peripheral.services else {
                return
            }

            // update our local model for observability
            device.stateContainer.services = services

            logger.debug("Discovered \(services) services for peripheral \(peripheral.debugIdentifier)")

            for service in services {
                let requestedCharacteristics = device.stateContainer.requestedCharacteristics?[service.uuid]

                // see peripheral(_:didDiscoverCharacteristicsFor:error:)
                peripheral.discoverCharacteristics(requestedCharacteristics, for: service)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if let error = error {
                logger.error("Error discovering characteristics: \(error.localizedDescription)")
                return
            }

            guard let characteristics = service.characteristics else {
                return
            }

            logger.debug("Discovered \(characteristics.count) characteristic(s) for service \(service.uuid)")

            for characteristic in characteristics {
                peripheral.discoverDescriptors(for: characteristic) // TODO: always do this?
            }

            Task {
                await device.discovered(characteristics: characteristics, for: service)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
            guard let descriptors = characteristic.descriptors else {
                return
            }

            // TODO: are we using that?
            logger.debug("Discovered descriptors for characteristic \(characteristic.debugIdentifier): \(descriptors)")
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            Task {
                if let error {
                    await device.receivedUpdatedValue(for: characteristic, result: .failure(error))
                } else if let value = characteristic.value {
                    await device.receivedUpdatedValue(for: characteristic, result: .success(value))
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            Task {
                if let error {
                    await device.receivedWriteResponse(for: characteristic, result: .failure(error))
                } else if let value = characteristic.value {
                    await device.receivedWriteResponse(for: characteristic, result: .success(value))
                }
            }
        }

        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            Task {
                await device.receivedReadyNotification()
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                logger.error("Error changing notification state: \(error.localizedDescription)")
                return
            }


            if characteristic.isNotifying {
                logger.log("Notification began on \(characteristic.uuid.uuidString)")

                if characteristic.properties.contains(.read) { // read the initial value
                    peripheral.readValue(for: characteristic)
                }
            } else {
                logger.log("Notification stopped on \(characteristic.uuid.uuidString).")
            }
        }
    }
} // swiftlint:disable:this file_length
