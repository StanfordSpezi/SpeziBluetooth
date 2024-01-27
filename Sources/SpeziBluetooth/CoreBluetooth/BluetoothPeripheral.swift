//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation
import OSLog


/// A nearby Bluetooth peripheral.
///
/// This class represents a nearby Bluetooth peripheral.
/// You may connect to the peripheral and read or write its characteristic data.
///
/// ## Topics
///
/// ### Peripheral State
/// - ``id``
/// - ``name``
/// - ``state``
/// - ``rssi``
/// - ``advertisementData``
///
/// ### Accessing Services
/// - ``services``
/// - ``getService(id:)``
/// - ``getCharacteristic(id:on:)``
///
/// ### Managing Connection
/// - ``connect()``
/// - ``disconnect()``
///
/// ### Reading a value
/// - ``read(characteristic:)``
///
/// ### Writing a value
/// - ``write(data:for:)``
/// - ``writeWithoutResponse(data:for:)``
///
/// ### Notifications and handling changes
/// - ``enableNotifications(_:serviceId:characteristicId:)``
/// - ``registerOnChangeHandler(service:characteristic:_:)``
/// - ``registerOnChangeHandler(for:_:)``
/// - ``OnChangeRegistration``
///
/// ### Retrieving the latest signal strength
/// - ``readRSSI()``
public actor BluetoothPeripheral { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothDevice")

    private weak var manager: BluetoothManager?
    private let peripheral: CBPeripheral

    private let delegate: Delegate
    private let stateObserver: KVOStateObserver<BluetoothPeripheral>

    /// Ongoing accessed indexed by characteristic uuid.
    private var ongoingAccesses: [CBCharacteristic: CharacteristicAccessContinuation] = [:]
    /// Continuation for the current write without response access.
    private var writeWithoutResponseAccess: [CheckedContinuation<Void, Never>] = []
    /// Continuation for a currently ongoing rssi read access.
    private var rssiReadAccess: [CheckedContinuation<Int, Error>] = []

    /// On-change handler registrations for all characteristics.
    private var onChangeHandlers: [CharacteristicLocator: [UUID: (Data) -> Void]] = [:]
    /// The list of characteristics that are requested to enable notifications.
    private var notifyRequested: Set<CharacteristicLocator> = []

    /// Observable state container for local state.
    private let stateContainer: PeripheralStateContainer

    nonisolated var cbPeripheral: CBPeripheral {
        peripheral
    }

    /// The name of the peripheral.
    public nonisolated var name: String? {
        stateContainer.name
    }

    /// The current signal strength.
    ///
    /// This value is automatically updated when the device is advertising.
    /// Once the device establishes a connection this has to be manually updated.
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
    public nonisolated var services: [GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        stateContainer.services
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

        self.stateContainer = PeripheralStateContainer(
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
    /// - Note: This method returns as soon as the request to connect was processed locally. It does
    ///     not wait till the connection was completed successfully.
    ///
    /// - Note: You might want to verify via the ``AdvertisementData/isConnectable`` property that the device is connectable.
    public func connect() async {
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

    /// Retrieve a service.
    /// - Parameter id: The Bluetooth service id.
    /// - Returns: The service instance if present.
    public nonisolated func getService(id: CBUUID) -> GATTService? {
        services?.first { service in
            service.uuid == id
        }
    }

    /// Retrieve a characteristic.
    /// - Parameters:
    ///   - characteristicId: The Bluetooth characteristic id.
    ///   - serviceId: The Bluetooth service id.
    /// - Returns: The characteristic instance if present.
    public nonisolated func getCharacteristic(id characteristicId: CBUUID, on serviceId: CBUUID) -> GATTCharacteristic? {
        getService(id: serviceId)?.getCharacteristic(id: characteristicId)
    }

    func handleConnect() {
        guard let manager else {
            logger.warning("Tried handling connection attempt for an orphaned bluetooth peripheral!")
            return
        }

        if let description = manager.findDeviceDescription(for: advertisementData),
           let services = description.services {
            stateContainer.requestedCharacteristics = services.reduce(into: [CBUUID: Set<CharacteristicDescription>?]()) { result, configuration in
                if let characteristics = configuration.characteristics {
                    result[configuration.serviceId, default: []]?.formUnion(characteristics)
                } else if result[configuration.serviceId] == nil {
                    result[configuration.serviceId] = .some(nil)
                }
            }
        } else {
            // all services will be discovered
            stateContainer.requestedCharacteristics = nil
        }

        self.stateContainer.state = .init(from: peripheral.state) // ensure that it is updated instantly.

        logger.debug("Discovering services for \(self.peripheral.debugIdentifier) ...")
        peripheral.discoverServices(stateContainer.requestedCharacteristics.map { Array($0.keys) })
    }

    /// Handles a disconnect or failed connection attempt.
    nonisolated func handleDisconnect(disconnectActivityInterval: TimeInterval = 0) {
        self.stateContainer.state = .init(from: peripheral.state) // ensure that it is updated instantly.
        self.stateContainer.lastActivity = Date.now - disconnectActivityInterval

        Task {
            await clearAccesses()
        }
    }

    func clearAccesses() {
        for continuation in writeWithoutResponseAccess {
            continuation.resume()
        }
        writeWithoutResponseAccess.removeAll()

        for continuation in rssiReadAccess {
            continuation.resume(throwing: BluetoothError.notPresent)
        }
        rssiReadAccess.removeAll()

        let ongoingAccesses = ongoingAccesses
        self.ongoingAccesses.removeAll()

        for (_, access) in ongoingAccesses {
            switch access {
            case let .read(continuations, queued):
                for continuation in continuations {
                    continuation.resume(throwing: BluetoothError.notPresent)
                }
                for queue in queued {
                    queue.resume()
                }
            case let .write(continuation, queued):
                continuation.resume(throwing: BluetoothError.notPresent)
                for queue in queued {
                    queue.resume()
                }
            }
        }
    }

    nonisolated func update(advertisement: AdvertisementData, rssi: Int) {
        self.stateContainer.lastActivity = .now // fine to be non-isolated. We always just write the latest data

        // this could be a problem to be non-isolated, however, we know this will always come from the Bluetooth queue that is serial.
        if let localName = advertisementData.localName,
           stateContainer.name != localName {
            stateContainer.name = localName
        }
        stateContainer.advertisementData = advertisement
        if stateContainer.rssi != rssi {
            stateContainer.rssi = rssi
        }
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

    /// Register a on-change handler for a characteristic.
    ///
    /// This method registers a on-change handler for the provided characteristic.
    ///
    /// - Note: Make sure that you don't create a retain cycle if the provided closure captures `self`.
    ///
    /// - Parameters:
    ///   - characteristic: The characteristic to register notifications for.
    ///   - onChange: The on-change handler.
    /// - @Returns: Returns the ``OnChangeRegistration`` that can be used to cancel and deregister the on-change handler.
    public func registerOnChangeHandler(
        for characteristic: GATTCharacteristic,
        _ onChange: @escaping (Data) -> Void
    ) throws -> OnChangeRegistration {
        guard let service = characteristic.service else {
            throw BluetoothError.notPresent
        }

        return registerOnChangeHandler(service: service.uuid, characteristic: characteristic.uuid, onChange)
    }

    /// Register a on-change handler for a characteristic.
    ///
    /// This method registers a on-change handler for the provide service and characteristic id.
    ///
    /// - Note: Make sure that you don't create a retain cycle if the provided closure captures `self`.
    ///
    /// - Parameters:
    ///   - service: The service uuid.
    ///   - characteristic: The characteristic uuid.
    ///   - onChange: The on-change handler.
    /// - @Returns: Returns the ``OnChangeRegistration`` that can be used to cancel and deregister the on-change handler.
    public func registerOnChangeHandler(
        service: CBUUID,
        characteristic: CBUUID,
        _ onChange: @escaping (Data) -> Void
    ) -> OnChangeRegistration {
        let locator = CharacteristicLocator(serviceId: service, characteristicId: characteristic)
        let id = UUID() // on-change handler id, used internally

        onChangeHandlers[locator, default: [:]]
            .updateValue(onChange, forKey: id)

        return OnChangeRegistration(peripheral: self, locator: locator, handlerId: id)
    }

    /// Enable or disable notifications for a given characteristic.
    ///
    /// - Tip: It is not required that the device is connected. Notifications will be automatically enabled for the
    /// respective characteristic upon device discovery.
    ///
    /// - Parameters:
    ///   - enabled: Enable or disable notifications.
    ///   - serviceId: The service the characteristic lives on.
    ///   - characteristicId: The characteristic to notify about.
    public func enableNotifications(_ enabled: Bool = true, serviceId: CBUUID, characteristicId: CBUUID) {
        // swiftlint:disable:previous function_default_parameter_at_end
        let id = CharacteristicLocator(serviceId: serviceId, characteristicId: characteristicId)
        if enabled {
            notifyRequested.insert(id)
        } else {
            notifyRequested.remove(id)
        }

        // if setting notify doesn't work here, we do it upon discovery of the characteristics
        trySettingNotifyValue(enabled, serviceId: serviceId, characteristicId: characteristicId)
    }

    func deregisterOnChange(_ registration: OnChangeRegistration) {
        deregisterOnChange(locator: registration.locator, handlerId: registration.handlerId)
    }

    func deregisterOnChange(locator: CharacteristicLocator, handlerId: UUID) {
        onChangeHandlers[locator]?.removeValue(forKey: handlerId)
    }

    private func trySettingNotifyValue(_ notify: Bool, serviceId: CBUUID, characteristicId: CBUUID) {
        guard let characteristic = getCharacteristic(id: characteristicId, on: serviceId) else {
            return
        }

        if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
            peripheral.setNotifyValue(notify, for: characteristic.underlyingCharacteristic)
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

    /// Write the value of a characteristic expecting a confirmation.
    ///
    /// Writes the value of a characteristic expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.3 Write Characteristic Value.
    ///
    /// - Parameters:
    ///   - data: The value to write.
    ///   - characteristic: The characteristic to which the value is written.
    /// - Returns: The response from the device.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    public func write(data: Data, for characteristic: GATTCharacteristic) async throws {
        let characteristic = characteristic.underlyingCharacteristic
        while ongoingAccesses[characteristic] != nil {
            await queueRWAccess(for: characteristic)
        }

        try await withCheckedThrowingContinuation { continuation in
            // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
            ongoingAccesses.updateValue(.write(continuation), forKey: characteristic)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    /// Write the value of a characteristic without expecting a confirmation.
    ///
    /// Writes the value of a characteristic without expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.1 Write Without Response.
    ///
    /// - Parameters:
    ///   - data: The value to write.
    ///   - characteristic: The characteristic to which the value is written.
    public func writeWithoutResponse(data: Data, for characteristic: GATTCharacteristic) async {
        guard writeWithoutResponseAccess.isEmpty else {
            await withCheckedContinuation { continuation in
                writeWithoutResponseAccess.append(continuation)
            }
            return
        }

        let characteristic = characteristic.underlyingCharacteristic

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
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    public func read(characteristic: GATTCharacteristic) async throws -> Data {
        let characteristic = characteristic.underlyingCharacteristic

        // if there is already a read for this characteristic, we just piggy back onto it
        if case .read(var continuations, let queued) = ongoingAccesses[characteristic] {
            return try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
                // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
                ongoingAccesses.updateValue(.read(continuations, queued: queued), forKey: characteristic)
            }
        }

        while ongoingAccesses[characteristic] != nil {
            // otherwise there is a write and we wait for its completion before we read again
            await queueRWAccess(for: characteristic)
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

    private func queueRWAccess(for characteristic: CBCharacteristic) async {
        guard let access = ongoingAccesses[characteristic] else {
            return
        }

        switch access {
        case .read(let readContinuation, var queued):
            await withCheckedContinuation { continuation in
                queued.append(continuation)
                // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
                ongoingAccesses.updateValue(.read(readContinuation, queued: queued), forKey: characteristic)
            }
        case .write(let writeContinuation, var queued):
            await withCheckedContinuation { continuation in
                queued.append(continuation)
                // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
                ongoingAccesses.updateValue(.write(writeContinuation, queued: queued), forKey: characteristic)
            }
        }
    }

    private nonisolated func didDiscoverCharacteristics(for service: CBService) {
        guard let gattService = getService(id: service.uuid) else {
            return
        }

        gattService.didDiscoverCharacteristics()
    }

    private nonisolated func propagateChanges(for characteristic: CBCharacteristic) {
        guard let service = characteristic.service,
              let gattCharacteristic = getCharacteristic(id: characteristic.uuid, on: service.uuid) else {
            return
        }

        gattCharacteristic.update()
    }
}


extension BluetoothPeripheral: Identifiable {
    /// The internally managed identifier for the peripheral.
    public nonisolated var id: UUID {
        peripheral.identifier
    }
}

extension BluetoothPeripheral: KVOReceiver {
    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) async {
        switch keyPath {
        case \CBPeripheral.state:
            // force cast is okay as we implicitly verify the type using the KeyPath in the case statement.
            self.stateContainer.state = .init(from: value as! CBPeripheralState) // swiftlint:disable:this force_cast
        default:
            break
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
            guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
                continue
            }

            let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)

            if notifyRequested.contains(locator) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        // check if we discover descriptors
        guard let requestedCharacteristics = stateContainer.requestedCharacteristics,
              let descriptions = requestedCharacteristics[service.uuid] else {
            return
        }

        for characteristic in characteristics {
            guard let description = descriptions?.first(where: { $0.characteristicId == characteristic.uuid }) else {
                continue
            }

            if description.discoverDescriptors {
                peripheral.discoverDescriptors(for: characteristic)
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
        if case let .read(continuations, queued) = ongoingAccesses[characteristic] {
            ongoingAccesses[characteristic] = nil
            
            if case let .failure(error) = result {
                logger.debug("Characteristic read for \(characteristic.debugIdentifier) returned with error: \(error)")
            }

            for continuation in continuations {
                continuation.resume(with: result)
            }

            for queue in queued {
                queue.resume()
            }
        }

        switch result {
        case let .success(data):
            guard let service = characteristic.service else {
                break
            }

            let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)

            for handler in onChangeHandlers[locator, default: [:]].values {
                handler(data)
            }
        case let .failure(error):
            logger.debug("Received unsolicited value update error for \(characteristic.debugIdentifier): \(error)")
        }
    }

    fileprivate func receivedWriteResponse(for characteristic: CBCharacteristic, result: Result<Void, Error>) {
        propagateChanges(for: characteristic)

        guard case let .write(continuation, queued) = ongoingAccesses[characteristic] else {
            logger.warning("Received write response for \(characteristic.debugIdentifier) without an ongoing access. Discarding write ...")
            return
        }

        ongoingAccesses[characteristic] = nil

        if case let .failure(error) = result {
            logger.debug("Characteristic write for \(characteristic.debugIdentifier) returned with error: \(error)")
        }

        continuation.resume(with: result)

        for queue in queued {
            queue.resume()
        }
    }
}


extension BluetoothPeripheral: CustomDebugStringConvertible {
    public nonisolated var debugDescription: String {
        cbPeripheral.debugIdentifier
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
            device.stateContainer.services?.removeAll(where: { invalidatedServices.contains($0.underlyingService) })

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
            device.stateContainer.services = services.map { service in
                GATTService(service: service)
            }

            logger.debug("Discovered \(services) services for peripheral \(peripheral.debugIdentifier)")

            for service in services {
                guard let requestedCharacteristicsDescriptions = device.stateContainer.requestedCharacteristics?[service.uuid] else {
                    continue
                }

                let requestedCharacteristics = requestedCharacteristicsDescriptions?.map { $0.characteristicId }

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

            device.didDiscoverCharacteristics(for: service)

            Task {
                await device.discovered(characteristics: characteristics, for: service)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
            guard let descriptors = characteristic.descriptors else {
                return
            }

            logger.debug("Discovered descriptors for characteristic \(characteristic.debugIdentifier): \(descriptors)")
            device.propagateChanges(for: characteristic)
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            // make sure value is propagated beforehand
            device.propagateChanges(for: characteristic)

            Task {
                if let error {
                    await device.receivedUpdatedValue(for: characteristic, result: .failure(error))
                } else if let value = characteristic.value {
                    await device.receivedUpdatedValue(for: characteristic, result: .success(value))
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            // TODO: does this change the .value property (if not, we should?)
            print("Value after write is now \(characteristic.value?.hexString() ?? "nil")")
            Task {
                if let error {
                    await device.receivedWriteResponse(for: characteristic, result: .failure(error))
                } else {
                    await device.receivedWriteResponse(for: characteristic, result: .success(()))
                }
            }
        }

        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            Task {
                await device.receivedReadyNotification() // TODO: again, does this change the .value property
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                // TODO: this happens sometimes with: The attribute could not be found. (for default notify true!)
                logger.error("Error changing notification state: \(error.localizedDescription)")
                return
            }

            device.propagateChanges(for: characteristic)


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
