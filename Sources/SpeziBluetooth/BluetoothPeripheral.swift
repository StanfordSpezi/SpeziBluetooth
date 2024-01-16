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
    case read(_ continuation: CheckedContinuation<Data, Error>)
    case write(_ continuation: CheckedContinuation<Data, Error>)
}


struct Id: Hashable, CustomStringConvertible { // TODO: rename
    let serviceId: CBUUID
    let characteristicId: CBUUID

    var description: String {
        "(service: \(serviceId.uuidString), characteristic: \(characteristicId.uuidString))"
    }
}

/// A dedicated state container for a ``BluetoothPeripheral``.
///
/// Main motivation is to have `BluetoothPeripheral` be implemented as an actor and moving state
/// into a separate state container that is `@Observable`.
@Observable
private final class BluetoothPeripheralState {
    var name: String?
    var rssi: Int?
    var state: PeripheralState
    var lastActivity: Date
    var services: [CBService]? // swiftlint:disable:this discouraged_optional_collection


    init(name: String?, rssi: Int?, state: CBPeripheralState, lastActivity: Date = .now) {
        self.name = name
        self.rssi = rssi
        self.state = .init(from: state)
        self.lastActivity = lastActivity
    }
}


public actor BluetoothPeripheral: Identifiable, KVOReceiver { // TODO: make it Equatable for easy onChange?
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothDevice")

    private weak var manager: BluetoothManager?
    private let peripheral: CBPeripheral
    /// The list of requested characteristic uuids indexed by service uuids.
    private let requestedCharacteristics: [CBUUID: [CBUUID]] // TODO: check if that is queried often and a set makes sense?

    private let delegate: Delegate
    private let stateObserver: KVOStateObserver<BluetoothPeripheral>

    /// Ongoing accessed indexed by characteristic uuid.
    private var ongoingAccesses: [CBCharacteristic: AccessorContinuation] = [:]
    /// Continuation for the current write without response access.
    private var writeWithoutResponseAccess: CheckedContinuation<Void, Never>?
    /// Continuation for a currently ongoing rssi read access.
    private var rssiReadAccess: CheckedContinuation<Int, Error>?

    // TODO: add handlers possibility when no instance is present?
    private var notificationHandlers: [CBCharacteristic: [BluetoothNotificationHandler]] = [:]

    /// Observable state container for local state.
    private let stateContainer: BluetoothPeripheralState

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


    init(manager: BluetoothManager, peripheral: CBPeripheral, requestedCharacteristics: [CBUUID: [CBUUID]], rssi: NSNumber) {
        self.manager = manager
        self.peripheral = peripheral
        self.requestedCharacteristics = requestedCharacteristics

        self.stateContainer = BluetoothPeripheralState(name: peripheral.name, rssi: rssi.intValue, state: peripheral.state)

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

        // TODO: block ongoing accesses?
        // TODO: will ongoing writes, reads, ... be cancelled??
    }

    nonisolated func handleConnect() { // TODO: can this stay nonisolated?
        // TODO: build and parse Device instance

        peripheral.discoverServices(Array(requestedCharacteristics.keys)) // TODO: specfiy all request services
        // TODO: search device type for characteristics ids!

        // TODO: what do we do, if we don't find a request service Id (and characteristic id?)?
    }

    nonisolated func handleDisconnect(disconnectActivityInterval: TimeInterval) {
        // TODO: throw ongoing promises with .notConnected?

        self.stateContainer.lastActivity = Date.now - disconnectActivityInterval
    }

    nonisolated func markActivity() {
        // fine to be non-isolated. We always just write the current time.
        self.stateContainer.lastActivity = .now
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
            return // TODO: does this check make sense?
        }

        // we need to unsubscribe before we cancel the connection
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? []  where characteristic.isNotifying {
                // TODO: filter against a local list?
                peripheral.setNotifyValue(false, for: characteristic)
            }
        }
    }

    public func write(data: Data, for characteristic: CBCharacteristic) async throws -> Data { // TODO: update docs!
        guard case .connected = peripheral.state else {
            throw BluetoothError.notConnected
        }

        // TODO: logger!

        guard ongoingAccesses[characteristic] == nil else {
            throw BluetoothError.concurrentCharacteristicAccess
        }

        // TODO: timeout?
        return try await withCheckedThrowingContinuation { continuation in
            // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
            ongoingAccesses.updateValue(.write(continuation), forKey: characteristic)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    public func writeWithoutResponse(data: Data, for characteristic: CBCharacteristic) async throws {
        guard case .connected = peripheral.state else {
            throw BluetoothError.notConnected
        }

        // TODO: logger!
        /*
         let hexDescription = data.reduce(into: "") {
         $0.append(String(format: "%02x", $1))
         }
         logger.debug("Write \(data.count) bytes: \(hexDescription)")
         */

        guard writeWithoutResponseAccess == nil else {
            // TODO: can we just await the current continuation to sync the whole thing?
            throw BluetoothError.concurrentCharacteristicAccess
        }

        // TODO: timeout???
        await withCheckedContinuation { continuation in
            writeWithoutResponseAccess = continuation
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }

    public func read(characteristic: CBCharacteristic) async throws -> Data {
        guard case .connected = peripheral.state else {
            throw BluetoothError.notConnected
        }

        guard ongoingAccesses[characteristic] == nil else {
            // TODO: could just piggy pack on an existing read?
            throw BluetoothError.concurrentCharacteristicAccess
        }

        // TODO: timeout?
        return try await withCheckedThrowingContinuation { continuation in
            // using updateValue as of https://github.com/apple/swift/issues/63156. Revert to subscript access with Swift 5.10
            ongoingAccesses.updateValue(.read(continuation), forKey: characteristic)
            peripheral.readValue(for: characteristic)
        }
    }

    public func readRSSI() async throws -> Int {
        guard case .connected = peripheral.state else {
            throw BluetoothError.notConnected
        }

        guard rssiReadAccess == nil else {
            // TODO: piggy back on the current continuation?
            throw BluetoothError.concurrentCharacteristicAccess
        }

        return try await withCheckedThrowingContinuation { continuation in
            rssiReadAccess = continuation
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

        guard let rssiReadAccess else {
            return
        }
        self.rssiReadAccess = nil

        if let error {
            // TODO: can we map the errors in general?
            rssiReadAccess.resume(throwing: error)
        } else {
            rssiReadAccess.resume(returning: rssi)
        }
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
        guard let writeWithoutResponseAccess else {
            return
        }

        self.writeWithoutResponseAccess = nil
        writeWithoutResponseAccess.resume()
    }

    fileprivate func receivedUpdatedValue(for characteristic: CBCharacteristic, result: Result<Data, Error>) async {
        // TODO: update `Characteristic` properties of device model!
        if case let .read(continuation) = ongoingAccesses[characteristic] {
            ongoingAccesses[characteristic] = nil

            if case let .failure(error) = result {
                // TODO: update log name for characteristic (service+characteristic comby)
                logger.debug("Characteristic read for \(characteristic.uuid) returned with error: \(error)")
            }

            continuation.resume(with: result)
        } else {
            switch result {
            case let .success(data):
                for handler in notificationHandlers[characteristic, default: []] {
                    await handler(data)
                }
            case let .failure(error):
                logger.debug("Received unsolicited value update error for \(characteristic.uuid): \(error)") // TODO logName!
            }
        }
    }

    fileprivate func receivedWriteResponse(for characteristic: CBCharacteristic, result: Result<Data, Error>) {
        // TODO: update `Characteristic` properties of device model!
        guard case let .write(continuation) = ongoingAccesses[characteristic] else {
            // TODO: log that we had a write without continuation???
            return
        }

        ongoingAccesses[characteristic] = nil

        if case let .failure(error) = result {
            // TODO: char logName
            logger.debug("Characteristic write for \(characteristic.uuid) returned with error: \(error)")
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

        private unowned var device: BluetoothPeripheral!

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
            device.stateContainer.services = peripheral.services

            for service in services {
                // TODO: support querying all characteristics!
                guard let requestedCharacteristics = device.requestedCharacteristics[service.uuid] else {
                    continue
                }

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
                return // TODO: verify against device.requestedCharacteristics?
            }

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
            // TODO: here and above, we have to check for race condition or thread access?

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

                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            } else {
                logger.log("Notification stopped on \(characteristic.uuid.uuidString). Disconnecting")
                // TODO: why? cleanup()
            }
        }
    }
}
