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


enum AccessorContinuation {
    case read(_ continuation: [CheckedContinuation<Data, Error>])
    case write(_ continuation: CheckedContinuation<Data, Error>)
}


/// A dedicated state container for a ``BluetoothPeripheral``.
///
/// Main motivation is to have `BluetoothPeripheral` be implemented as an actor and moving state
/// into a separate state container that is `@Observable`.
@Observable
private final class BluetoothPeripheralState {
    var name: String?
    var rssi: Int?
    var advertisementData: AdvertisementData
    var state: PeripheralState
    var lastActivity: Date
    var services: [CBService]? // swiftlint:disable:this discouraged_optional_collection

    /// The list of requested characteristic uuids indexed by service uuids.
    var requestedCharacteristics: [CBUUID: [CBUUID]]? // swiftlint:disable:this discouraged_optional_collection

    init(name: String?, rssi: Int?, advertisementData: AdvertisementData, state: CBPeripheralState, lastActivity: Date = .now) {
        self.name = name
        self.advertisementData = advertisementData
        self.rssi = rssi
        self.state = .init(from: state)
        self.lastActivity = lastActivity
    }
}


public actor BluetoothPeripheral: Identifiable, KVOReceiver { // TODO: make it Equatable for easy onChange?
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

    // TODO: add handlers possibility when no instance is present?
    private var notificationHandlers: [CBCharacteristic: [BluetoothNotificationHandler]] = [:]

    /// Observable state container for local state.
    private let stateContainer: BluetoothPeripheralState

    // TODO docs: all the state properties

    nonisolated var cbPeripheral: CBPeripheral {
        peripheral
    }

    public nonisolated var id: UUID {
        peripheral.identifier
    }

    public nonisolated var name: String? {
        stateContainer.name
    }

    public nonisolated var rssi: Int? {
        stateContainer.rssi
    }

    public nonisolated var advertisementData: AdvertisementData {
        stateContainer.advertisementData
    }

    public nonisolated var state: PeripheralState {
        stateContainer.state
    }

    /// The list of discovery services.
    ///
    /// Services are discovered automatically upon connection
    public nonisolated var services: [CBService]? { // swiftlint:disable:this discouraged_optional_collection
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

    public func connect() async {
        guard let manager else {
            logger.warning("Tried to connect an orphaned bluetooth peripheral!")
            return
        }

        await manager.connect(peripheral: self)
    }

    public func disconnect() {
        guard let manager else {
            logger.warning("Tried to disconnect an orphaned bluetooth peripheral!")
            return
        }

        removeAllNotifications()

        manager.disconnect(peripheral: self)

        // TODO: will ongoing writes, reads, ... be cancelled??
    }

    func handleConnect() {
        if let configuration = manager?.discoveryConfiguration(for: advertisementData) {
            stateContainer.requestedCharacteristics = configuration.services.reduce(into: [:]) { result, configuration in
                result[configuration.serviceId, default: []].append(contentsOf: configuration.characteristics)
            }
        } else {
            stateContainer.requestedCharacteristics = nil // all services will be discovered
        }

        logger.debug("Discovering services for \(self.peripheral.debugIdentifier) ...")
        peripheral.discoverServices(stateContainer.requestedCharacteristics.map { Array($0.keys) })

        // TODO: keep in mind with the DSL API, what if we don't find something that is declared (service, characteristic)?
    }

    nonisolated func handleDisconnect(disconnectActivityInterval: TimeInterval) {
        // TODO: throw ongoing promises with .notConnected?

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

    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) async {
        switch keyPath {
        case \CBPeripheral.state:
            self.stateContainer.state = .init(from: value as! CBPeripheralState)
        default:
            break
        }
    }

    // TODO: document potential retain cycles
    public func registerNotifications(for characteristic: CBCharacteristic, _ handler: @escaping BluetoothNotificationHandler) {
        notificationHandlers[characteristic, default: []].append(handler)
        // TODO: return a registration to remove it again?

        // as we get a characteristic instance
        peripheral.setNotifyValue(true, for: characteristic)
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

    public func write(data: Data, for characteristic: CBCharacteristic) async throws -> Data { // TODO: update docs!
        guard ongoingAccesses[characteristic] == nil else {
            throw BluetoothError.concurrentWriteCharacteristicAccess
        }

        return try await withCheckedThrowingContinuation { continuation in
            // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
            ongoingAccesses.updateValue(.write(continuation), forKey: characteristic)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

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
        for characteristic in characteristics where notificationHandlers[characteristic] != nil {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    fileprivate func invalidated(services: [CBService]) {
        // TODO: do we need to remove any characteristic state???
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
        } else {
            switch result {
            case let .success(data):
                for handler in notificationHandlers[characteristic, default: []] {
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
            // TODO: does this change our ongoing CBCharacteristic instances?? (Cancel Continuations, what is with notification handlers?)

            Task {
                await device.invalidated(services: invalidatedServices)

                peripheral.discoverServices(serviceIds)
            }
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

            Task {
                await device.discovered(characteristics: characteristics, for: service)
            }
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
}
