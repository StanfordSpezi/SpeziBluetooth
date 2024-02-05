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
    /// The serial DispatchQueue shared by the Bluetooth Manager.
    private let bluetoothExecutor: BluetoothSerialExecutor

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        bluetoothExecutor.asUnownedSerialExecutor()
    }

    private weak var manager: BluetoothManager?
    private let peripheral: CBPeripheral

    private let delegate: Delegate
    private let stateObserver: KVOStateObserver<BluetoothPeripheral>

    /// Observable state container for local state.
    private let stateContainer: PeripheralStateContainer


    /// Ongoing accessed per characteristic.
    private var characteristicAccesses = CharacteristicAccesses()
    /// Protecting concurrent access to an ongoing write without response.
    private let writeWithoutResponseAccess = AsyncSemaphore()
    /// Continuation for the current write without response access.
    private var writeWithoutResponseContinuation: CheckedContinuation<Void, Never>?
    /// Protecting concurrent access to an ongoing rssi read access.
    private let rssiAccess = AsyncSemaphore()
    /// Continuation for a currently ongoing rssi read access.
    private var rssiContinuation: CheckedContinuation<Int, Error>?

    /// On-change handler registrations for all characteristics.
    private var onChangeHandlers: [CharacteristicLocator: [UUID: (Data) -> Void]] = [:]
    /// The list of characteristics that are requested to enable notifications.
    private var notifyRequested: Set<CharacteristicLocator> = []


    /// The list of requested characteristic uuids indexed by service uuids.
    private var requestedCharacteristics: [CBUUID: Set<CharacteristicDescription>?]? // swiftlint:disable:this discouraged_optional_collection
    /// A set of service ids we are currently awaiting characteristics discovery for
    private var servicesAwaitingCharacteristicsDiscovery: Set<CBUUID> = []

    nonisolated var cbPeripheral: CBPeripheral {
        peripheral
    }


    /// The name of the peripheral.
    public var name: String? {
        localName ?? peripheralName
    }

    private(set) var localName: String? {
        get {
            stateContainer.localName
        }
        set {
            stateContainer.update(localName: newValue)
        }
    }

    private(set) var peripheralName: String? {
        get {
            stateContainer.peripheralName
        }
        set {
            stateContainer.update(peripheralName: newValue)
        }
    }

    /// The current signal strength.
    ///
    /// This value is automatically updated when the device is advertising.
    /// Once the device establishes a connection this has to be manually updated.
    public private(set) var rssi: Int {
        get {
            stateContainer.rssi
        }
        set {
            stateContainer.update(rssi: newValue)
        }
    }

    /// The advertisement data of the last bluetooth advertisement.
    public private(set) var advertisementData: AdvertisementData {
        get {
            stateContainer.advertisementData
        }
        set {
            stateContainer.update(advertisementData: newValue)
        }
    }

    /// The current peripheral device state.
    public internal(set) var state: PeripheralState {
        get {
            stateContainer.state
        }
        set {
            stateContainer.update(state: newValue)
        }
    }

    /// The list of discovered services.
    ///
    /// Services are discovered automatically upon connection
    public private(set) var services: [GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        get {
            stateContainer.services
        }
        set {
            if let newValue {
                stateContainer.assign(services: newValue)
            }
        }
    }

    var lastActivity: Date { // TODO: setter?
        get {
            if case .disconnected = peripheral.state {
                stateContainer.lastActivity
            } else {
                // we are currently connected or connecting/disconnecting, therefore last activity is defined as "now"
                .now
            }
        }
        set {
            stateContainer.update(lastActivity: newValue)
        }
    }


    init(
        manager: BluetoothManager,
        dispatchQueue: DispatchQueue,
        peripheral: CBPeripheral,
        advertisementData: AdvertisementData,
        rssi: Int
    ) {
        self.bluetoothExecutor = BluetoothSerialExecutor(dispatchQueue: dispatchQueue)

        self.manager = manager
        self.peripheral = peripheral

        self.stateContainer = PeripheralStateContainer(
            peripheralName: peripheral.name,
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
    public func connect() {
        guard let manager else {
            logger.warning("Tried to connect an orphaned bluetooth peripheral!")
            return
        }

        manager.assumeIsolated { manager in
            manager.connect(peripheral: self)
        }
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

        manager.assumeIsolated { manager in
            manager.disconnect(peripheral: self)
        }
        self.state = PeripheralState(from: peripheral.state) // ensure that it is updated instantly.
    }

    /// Retrieve a service.
    /// - Parameter id: The Bluetooth service id.
    /// - Returns: The service instance if present.
    public func getService(id: CBUUID) -> GATTService? {
        services?.first { service in
            service.uuid == id
        }
    }

    /// Retrieve a characteristic.
    /// - Parameters:
    ///   - characteristicId: The Bluetooth characteristic id.
    ///   - serviceId: The Bluetooth service id.
    /// - Returns: The characteristic instance if present.
    public func getCharacteristic(id characteristicId: CBUUID, on serviceId: CBUUID) -> GATTCharacteristic? {
        getService(id: serviceId)?.getCharacteristic(id: characteristicId)
    }

    func handleConnect() {
        guard let manager else {
            logger.warning("Tried handling connection attempt for an orphaned bluetooth peripheral!")
            return
        }

        let advertisementData = advertisementData

        if let description = manager.assumeIsolated({ $0.findDeviceDescription(for: advertisementData) }),
           let services = description.services {
            requestedCharacteristics = services.reduce(into: [CBUUID: Set<CharacteristicDescription>?]()) { result, configuration in
                if let characteristics = configuration.characteristics {
                    result[configuration.serviceId, default: []]?.formUnion(characteristics)
                } else if result[configuration.serviceId] == nil {
                    result[configuration.serviceId] = .some(nil)
                }
            }
        } else {
            // all services will be discovered
            requestedCharacteristics = nil
        }

        self.state = PeripheralState(from: peripheral.state) // ensure that it is updated instantly.

        logger.debug("Discovering services for \(self.peripheral.debugIdentifier) ...")
        let services = requestedCharacteristics.map { Array($0.keys) }
        
        if let services, services.isEmpty {
            stateContainer.signalFullyDiscovered()
        } else {
            peripheral.discoverServices(requestedCharacteristics.map { Array($0.keys) })
        }
    }

    /// Handles a disconnect or failed connection attempt.
    func handleDisconnect() { // TODO: check all these async accesses in the BluetoothManager!
        self.state = PeripheralState(from: peripheral.state) // ensure that it is updated instantly.

        // clear all the ongoing access

        characteristicAccesses.cancelAll()
        writeWithoutResponseAccess.cancelAll()
        rssiAccess.cancelAll()

        if let writeWithoutResponseContinuation {
            self.writeWithoutResponseContinuation = nil
            writeWithoutResponseContinuation.resume()
        }
        if let rssiContinuation {
            self.rssiContinuation = nil
            rssiContinuation.resume(throwing: CancellationError())
        }
    }

    func markLastActivity(_ lastActivity: Date = .now) {
        self.lastActivity = lastActivity
    }

    func update(advertisement: AdvertisementData, rssi: Int) { // TODO: separate method still necessary?
        self.localName = advertisementData.localName
        self.advertisementData = advertisement
        self.rssi = rssi
    }

    /// Determines if the device is considered stale.
    ///
    /// This is the case if the device is not connected and the last activity is longer in the past than
    /// the provided interval.
    /// - Parameter interval: The time interval after which the device is considered stale.
    /// - Returns: True if the device is considered stale given the above criteria.
    func isConsideredStale(interval: TimeInterval) -> Bool {
        peripheral.state == .disconnected && lastActivity.addingTimeInterval(interval) < .now
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
            throw BluetoothError.notPresent(service: nil, characteristic: characteristic.uuid)
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
        let access = characteristicAccesses.makeAccess(for: characteristic)
        try await access.waitCheckingCancellation()

        try await withCheckedThrowingContinuation { continuation in
            access.store(.write(continuation))
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
        do {
            try await writeWithoutResponseAccess.waitCheckingCancellation()
        } catch {
            // task got cancelled, so just throw away the written value
            return
        }

        await withCheckedContinuation { continuation in
            assert(writeWithoutResponseContinuation == nil, "writeWithoutResponseAccess was unexpectedly not nil")
            writeWithoutResponseContinuation = continuation
            peripheral.writeValue(data, for: characteristic.underlyingCharacteristic, type: .withoutResponse)
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

        let access = characteristicAccesses.makeAccess(for: characteristic)
        try await access.waitCheckingCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            access.store(.read(continuation))
            peripheral.readValue(for: characteristic)
        }
    }

    /// Retrieve the current RSSI value.
    ///
    /// Retrieves the current RSSI value for the peripheral while its connected.
    /// - Returns: The read rssi value.
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    public func readRSSI() async throws -> Int {
        try await rssiAccess.waitCheckingCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            assert(rssiContinuation == nil, "rssiAccess was unexpectedly not nil")
            rssiContinuation = continuation
            peripheral.readRSSI()
        }
    }

    private func didDiscoverCharacteristics(for service: CBService) {
        guard let gattService = getService(id: service.uuid) else {
            logger.error("Failed to retrieve service \(service.uuid) of discovered characteristics!")
            return
        }

        gattService.didDiscoverCharacteristics()
    }

    private func propagateChanges(for characteristic: CBCharacteristic) {
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
    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) {
        switch keyPath {
        case \CBPeripheral.state:
            // force cast is okay as we implicitly verify the type using the KeyPath in the case statement.
            self.state = PeripheralState(from: value as! CBPeripheralState) // swiftlint:disable:this force_cast
        default:
            break
        }
    }
}


// MARK: Delegate Accessors
extension BluetoothPeripheral { // TODO: inline some more of those methods?
    private func discovered(services: [CBService]) {
        logger.debug("Discovered \(services) services for peripheral \(self.peripheral.debugIdentifier)")

        for service in services {
            guard let requestedCharacteristicsDescriptions = requestedCharacteristics?[service.uuid] else {
                continue
            }

            let requestedCharacteristics = requestedCharacteristicsDescriptions?.map { $0.characteristicId }

            if let requestedCharacteristics, requestedCharacteristics.isEmpty {
                continue
            }

            servicesAwaitingCharacteristicsDiscovery.insert(service.uuid)
            peripheral.discoverCharacteristics(requestedCharacteristics, for: service)
        }

        if servicesAwaitingCharacteristicsDiscovery.isEmpty {
            stateContainer.signalFullyDiscovered()
        }
    }

    private func completeServiceDiscovery(for service: CBService) {
        servicesAwaitingCharacteristicsDiscovery.remove(service.uuid)
        if servicesAwaitingCharacteristicsDiscovery.isEmpty {
            stateContainer.signalFullyDiscovered()
        }
    }

    private func discovered(service: CBService, result: Result<Void, Error>) {
        completeServiceDiscovery(for: service) // ensure we keep track of all discoveries

        if case let .failure(error) = result {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            logger.warning("Characteristic discovery for service \(service.uuid) resulted in an empty list.")
            return
        }

        logger.debug("Discovered \(characteristics.count) characteristic(s) for service \(service.uuid): \(characteristics)")

        // automatically subscribe to discovered characteristics for which we have a handler subscribed!
        for characteristic in characteristics {
            guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
                continue
            }

            let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)

            if notifyRequested.contains(locator) {
                logger.debug("Automatically subscribing to discovered characteristic \(locator)...")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        // check if we discover descriptors
        guard let requestedCharacteristics = requestedCharacteristics,
              let descriptions = requestedCharacteristics[service.uuid] else {
            return
        }

        for characteristic in characteristics {
            guard let description = descriptions?.first(where: { $0.characteristicId == characteristic.uuid }) else {
                continue
            }

            if description.discoverDescriptors {
                logger.debug("Discovering descriptors for \(characteristic.debugIdentifier)...")
                peripheral.discoverDescriptors(for: characteristic)
            }
        }
    }

    private func receivedUpdatedValue(for characteristic: CBCharacteristic, result: Result<Data, Error>) {
        if case let .read(continuation) = characteristicAccesses.retrieveAccess(for: characteristic) {
            if case let .failure(error) = result {
                logger.debug("Characteristic read for \(characteristic.debugIdentifier) returned with error: \(error)")
            }

            continuation.resume(with: result)
        } else if case let .failure(error) = result {
            logger.debug("Received unsolicited value update error for \(characteristic.debugIdentifier): \(error)")
        }

        // notification handling
        guard case let .success(data) = result else {
            return
        }

        guard let service = characteristic.service else {
            logger.warning("Received updated value for characteristic \(characteristic.debugIdentifier) without associated service!")
            return
        }

        let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)
        for handler in onChangeHandlers[locator, default: [:]].values {
            handler(data)
        }
    }

    private func receivedWriteResponse(for characteristic: CBCharacteristic, result: Result<Void, Error>) {
        guard case let .write(continuation) = characteristicAccesses.retrieveAccess(for: characteristic) else {
            switch result {
            case .success:
                logger.warning("Received write response for \(characteristic.debugIdentifier) without an ongoing access. Discarding write ...")
            case let .failure(error):
                logger.warning("Received erroneous write response for \(characteristic.debugIdentifier) without an ongoing access: \(error)")
            }
            return
        }

        if case let .failure(error) = result {
            logger.debug("Characteristic write for \(characteristic.debugIdentifier) returned with error: \(error)")
        }

        continuation.resume(with: result)
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
            device.assumeIsolated { isolated in
                isolated.peripheralName = peripheral.name
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
            device.assumeIsolated { isolated in
                let rssi = RSSI.intValue
                isolated.rssi = rssi

                let result: Result<Int, Error>
                if let error {
                    result = .failure(error)
                } else {
                    result = .success(rssi)
                }

                guard let rssiContinuation = isolated.rssiContinuation else {
                    return
                }

                isolated.rssiContinuation = nil
                rssiContinuation.resume(with: result)
                assert(isolated.rssiAccess.signal(), "Signaled rssiAccess though no one was waiting")
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            // this is called if ...
            // 1) The peripheral removes a service from its database.
            // 2) The peripheral adds a new service to its database.
            // 3) The peripheral adds back a previously-removed service, but at a different location in the database.

            // so a service we requested might be gone now. Or might just have changed location. So, discover them to check if they moved location?

            device.assertIsolated("SerialExecutor is not the bluetooth dispatch queue.")

            let serviceIds = invalidatedServices.map { $0.uuid }
            logger.debug("Services modified, invalidating \(serviceIds)")

            // update our local model
            device.stateContainer.invalidateServices(serviceIds) // this assumes isolation

            peripheral.discoverServices(serviceIds)
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if let error {
                logger.error("Error discovering services: \(error.localizedDescription)")
                return
            }

            guard let services = peripheral.services else {
                logger.error("Discovered services but they weren't present!")
                return
            }

            device.assumeIsolated { isolated in
                // update our local model for observability
                isolated.services = services.map { service in
                    GATTService(service: service)
                }

                isolated.discovered(services: services)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            device.assumeIsolated { isolated in
                isolated.didDiscoverCharacteristics(for: service)

                if let error {
                    isolated.discovered(service: service, result: .failure(error))
                } else {
                    isolated.discovered(service: service, result: .success(()))
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
            guard let descriptors = characteristic.descriptors else {
                return
            }

            logger.debug("Discovered descriptors for characteristic \(characteristic.debugIdentifier): \(descriptors)")
            device.assumeIsolated { isolated in
                isolated.propagateChanges(for: characteristic)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            device.assumeIsolated { isolated in
                // make sure value is propagated beforehand
                isolated.propagateChanges(for: characteristic)

                if let error {
                    isolated.receivedUpdatedValue(for: characteristic, result: .failure(error))
                } else if let value = characteristic.value {
                    isolated.receivedUpdatedValue(for: characteristic, result: .success(value))
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            device.assumeIsolated { isolated in
                isolated.propagateChanges(for: characteristic)

                if let error {
                    isolated.receivedWriteResponse(for: characteristic, result: .failure(error))
                } else {
                    isolated.receivedWriteResponse(for: characteristic, result: .success(()))
                }
            }
        }

        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            device.assumeIsolated { isolated in
                guard let writeWithoutResponseContinuation = isolated.writeWithoutResponseContinuation else {
                    return
                }

                isolated.writeWithoutResponseContinuation = nil
                writeWithoutResponseContinuation.resume()
                assert(isolated.writeWithoutResponseAccess.signal(), "Signaled writeWithoutResponseAccess though no one was waiting")
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                logger.error("Error changing notification state for \(characteristic.uuid): \(error)")
                return
            }

            device.assumeIsolated { isolated in
                isolated.propagateChanges(for: characteristic)

                if characteristic.isNotifying {
                    logger.log("Notification began on \(characteristic.debugIdentifier)")

                    if characteristic.properties.contains(.read) { // read the initial value
                        peripheral.readValue(for: characteristic)
                    }
                } else {
                    logger.log("Notification stopped on \(characteristic.debugIdentifier).")
                }
            }
        }
    }
} // swiftlint:disable:this file_length
