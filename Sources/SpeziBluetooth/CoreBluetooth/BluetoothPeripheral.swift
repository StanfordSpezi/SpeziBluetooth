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
import SpeziFoundation


enum CharacteristicOnChangeHandler {
    case value(_ closure: (Data) -> Void)
    case instance(_ closure: (GATTCharacteristic?) -> Void)
}


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
/// - ``discarded``
/// - ``lastActivity``
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
public actor BluetoothPeripheral: BluetoothActor { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothDevice")
    /// The serial DispatchQueue shared by the Bluetooth Manager.
    let bluetoothQueue: DispatchSerialQueue

    private weak var manager: BluetoothManager?
    private let peripheral: CBPeripheral
    private let configuration: DeviceDescription

    private let delegate: Delegate
    private let stateObserver: KVOStateObserver<BluetoothPeripheral>

    /// Observable state container for local state.
    private let _storage: PeripheralStorage


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
    private var onChangeHandlers: [CharacteristicLocator: [UUID: CharacteristicOnChangeHandler]] = [:]
    /// The list of characteristics that are requested to enable notifications.
    private var notifyRequested: Set<CharacteristicLocator> = []


    /// The list of requested characteristic uuids indexed by service uuids.
    private var requestedCharacteristics: [CBUUID: Set<CharacteristicDescription>?]? // swiftlint:disable:this discouraged_optional_collection
    /// A set of service ids we are currently awaiting characteristics discovery for
    private var servicesAwaitingCharacteristicsDiscovery: Set<CBUUID> = []

    nonisolated var cbPeripheral: CBPeripheral {
        peripheral
    }

    nonisolated var unsafeState: PeripheralStorage {
        _storage
    }

    /// The name of the peripheral.
    ///
    /// Returns the name reported through the Generic Access Profile, otherwise falls back to the local name.
    nonisolated public var name: String? {
        _storage.name
    }


    /// The local name included in the advertisement.
    nonisolated public private(set) var localName: String? {
        get {
            _storage.localName
        }
        set {
            _storage.update(localName: newValue)
        }
    }

    nonisolated private(set) var peripheralName: String? {
        get {
            _storage.peripheralName
        }
        set {
            _storage.update(peripheralName: newValue)
        }
    }

    /// The current signal strength.
    ///
    /// This value is automatically updated when the device is advertising.
    /// Once the device establishes a connection this has to be manually updated.
    nonisolated public private(set) var rssi: Int {
        get {
            _storage.rssi
        }
        set {
            _storage.update(rssi: newValue)
        }
    }

    /// The advertisement data of the last bluetooth advertisement.
    nonisolated public private(set) var advertisementData: AdvertisementData {
        get {
            _storage.advertisementData
        }
        set {
            _storage.update(advertisementData: newValue)
        }
    }

    /// The current peripheral device state.
    nonisolated public internal(set) var state: PeripheralState {
        get {
            _storage.state
        }
        set {
            _storage.update(state: newValue)
        }
    }

    /// The list of discovered services.
    ///
    /// Services are discovered automatically upon connection
    nonisolated public private(set) var services: [GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        get {
            _storage.services
        }
        set {
            if let newValue {
                _storage.assign(services: newValue)
            }
        }
    }

    /// The last device activity.
    ///
    /// Returns the date of the last advertisement received from the device or the point in time the device disconnected.
    /// Returns `now` if the device is currently connected.
    nonisolated public private(set) var lastActivity: Date {
        get {
            if case .connected = state {
                // we are currently connected or connecting/disconnecting, therefore last activity is defined as "now"
                .now
            } else {
                _storage.lastActivity
            }
        }
        set {
            _storage.update(lastActivity: newValue)
        }
    }

    /// Indicates that the peripheral was discarded.
    ///
    /// For devices that were found through nearby device search, this property indicates that the device was discarded
    /// as it was considered stale and no new advertisement was received. This also happens when such a devices disconnects and no new
    /// advertisement is received.
    nonisolated public private(set) var discarded: Bool {
        get {
            _storage.discarded
        }
        set {
            _storage.update(discarded: newValue)
        }
    }


    init(
        manager: BluetoothManager,
        peripheral: CBPeripheral,
        configuration: DeviceDescription,
        advertisementData: AdvertisementData,
        rssi: Int
    ) {
        self.bluetoothQueue = manager.bluetoothQueue

        self.manager = manager
        self.peripheral = peripheral
        self.configuration = configuration

        self._storage = PeripheralStorage(
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
        // ensure that it is updated instantly.
        self.isolatedUpdate(of: \.state, PeripheralState(from: peripheral.state))
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

    func onChange<Value>(of keyPath: KeyPath<PeripheralStorage, Value>, perform closure: @escaping (Value) -> Void) {
        _storage.onChange(of: keyPath, perform: closure)
    }

    func handleConnect() {
        if let services = configuration.services {
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

        // ensure that it is updated instantly.
        self.isolatedUpdate(of: \.state, PeripheralState(from: peripheral.state))
        if discarded {
            self.isolatedUpdate(of: \.discarded, false)
        }

        logger.debug("Discovering services for \(self.peripheral.debugIdentifier) ...")
        let services = requestedCharacteristics.map { Array($0.keys) }
        
        if let services, services.isEmpty {
            _storage.signalFullyDiscovered()
        } else {
            peripheral.discoverServices(requestedCharacteristics.map { Array($0.keys) })
        }
    }

    /// Handles a disconnect or failed connection attempt.
    func handleDisconnect() {
        // ensure that it is updated instantly.
        self.isolatedUpdate(of: \.state, PeripheralState(from: peripheral.state))

        // clear all the ongoing access

        self.requestedCharacteristics = nil
        self.servicesAwaitingCharacteristicsDiscovery.removeAll()

        if let services {
            self.invalidateServices(Set(services.map { $0.uuid }))
        }

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

    func handleDiscarded() {
        isolatedUpdate(of: \.discarded, true)
    }

    func markLastActivity(_ lastActivity: Date = .now) {
        self.lastActivity = lastActivity
    }

    func update(advertisement: AdvertisementData, rssi: Int) {
        self.isolatedUpdate(of: \.localName, advertisement.localName)
        self.isolatedUpdate(of: \.advertisementData, advertisement)
        self.isolatedUpdate(of: \.rssi, rssi)
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
        registerCharacteristicOnChange(service: service, characteristic: characteristic, .value(onChange))
    }

    func registerOnChangeCharacteristicHandler(
        service: CBUUID,
        characteristic: CBUUID,
        _ onChange: @escaping (GATTCharacteristic?) -> Void
    ) -> OnChangeRegistration {
        registerCharacteristicOnChange(service: service, characteristic: characteristic, .instance(onChange))
    }

    private func registerCharacteristicOnChange(
        service: CBUUID,
        characteristic: CBUUID,
        _ onChange: CharacteristicOnChangeHandler
    ) -> OnChangeRegistration {
        let locator = CharacteristicLocator(serviceId: service, characteristicId: characteristic)
        let id = UUID() // on-change handler id, used internally

        let replaced = onChangeHandlers[locator, default: [:]]
            .updateValue(onChange, forKey: id)
        assert(replaced == nil, "onChangeHandlers are forced to be unique and shouldn't replace previous values.")

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

    func didRequestNotifications(serviceId: CBUUID, characteristicId: CBUUID) -> Bool {
        let id = CharacteristicLocator(serviceId: serviceId, characteristicId: characteristicId)
        return notifyRequested.contains(id)
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

        if characteristic.properties.supportsNotifications {
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

    private func synchronizeModel(for service: CBService) {
        guard let gattService = getService(id: service.uuid) else {
            logger.error("Failed to retrieve service \(service.uuid) of discovered characteristics!")
            return
        }

        // update our model with latest characteristics!
        let changeProtocol = gattService.synchronizeModel()

        for uuid in changeProtocol.removedCharacteristics {
            let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: uuid)
            for handler in onChangeHandlers[locator, default: [:]].values {
                if case let .instance(onChange) = handler {
                    onChange(nil) // signal removed characteristic!
                }
            }
        }

        for characteristic in changeProtocol.updatedCharacteristics {
            let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)
            for handler in onChangeHandlers[locator, default: [:]].values {
                if case let .instance(onChange) = handler {
                    onChange(characteristic)
                }
            }
        }
    }

    private func synchronizeModel(for characteristic: CBCharacteristic, capture: CBCharacteristicCapture) {
        guard let service = characteristic.service,
              let gattCharacteristic = getCharacteristic(id: characteristic.uuid, on: service.uuid) else {
            logger.error("Failed to locate GATTCharacteristic for provided one \(characteristic.uuid)")
            return
        }

        gattCharacteristic.synchronizeModel(capture: capture)
    }

    private func invalidateServices(_ ids: Set<CBUUID>) {
        guard let services else {
            return
        }

        for (index, service) in zip(services.indices, services).reversed() {
            guard ids.contains(service.uuid) else {
                continue
            }

            // Note: we iterate over the zipped array in reverse such that the indices stay valid if remove elements

            // the service was invalidated!
            self.services?.remove(at: index)

            // make sure we notify subscribed handlers about removed services!
            for characteristic in service.characteristics {
                let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)
                for handler in onChangeHandlers[locator, default: [:]].values {
                    if case let .instance(onChange) = handler {
                        onChange(nil) // signal removed characteristic!
                    }
                }
            }
        }
    }

    private func discovered(services: [CBService]) {
        // ids of currently maintained ids
        let existingServices = Set(self.services?.map { $0.uuid } ?? [])

        // if we re-discover services (e.g., if ones got invalidated), services might still be present. So only add new ones
        let addedServices = services
            .filter { !existingServices.contains($0.uuid) }
            .map {
                // we will discover characteristics for all services after that.
                GATTService(service: $0)
            }

        if let services = self.services {
            isolatedUpdate(of: \.services, services + addedServices)
        } else {
            isolatedUpdate(of: \.services, addedServices)
        }
    }

    private func isolatedUpdate<Value>(of keyPath: WritableKeyPath<BluetoothPeripheral, Value>, _ value: Value) {
        var peripheral = self
        peripheral[keyPath: keyPath] = value
    }

    deinit {
        if !_storage.discarded { // make sure peripheral gets discarded
            self.logger.debug("Discarding de-initialized peripheral \(self.id), \(self.name ?? "unnamed")")
            _storage.update(discarded: true) // TODO: test that this works for retrieved peripherals!
        }


        guard let manager else {
            self.logger.warning("Orphaned device \(self.id), \(self.name ?? "unnamed") was de-initialized")
            return
        }

        let id = id
        Task { @SpeziBluetooth in
            await manager.handlePeripheralDeinit(id: id)
        }
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
            self.isolatedUpdate(of: \.state, PeripheralState(from: value as! CBPeripheralState)) // swiftlint:disable:this force_cast
        default:
            break
        }
    }
}


// MARK: Delegate Accessors
extension BluetoothPeripheral {
    private func discovered(service: CBService) {
        guard let characteristics = service.characteristics else {
            logger.warning("Characteristic discovery for service \(service.uuid) resulted in an empty list.")
            return
        }

        logger.debug("Discovered \(characteristics.count) characteristic(s) for service \(service.uuid): \(characteristics)")

        // automatically subscribe to discovered characteristics for which we have a handler subscribed!
        for characteristic in characteristics {
            // pull initial value if none is present
            if characteristic.value == nil && characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }

            // enable notifications if registered
            if characteristic.properties.supportsNotifications {
                let locator = CharacteristicLocator(serviceId: service.uuid, characteristicId: characteristic.uuid)

                if notifyRequested.contains(locator) {
                    logger.debug("Automatically subscribing to discovered characteristic \(locator)...")
                    peripheral.setNotifyValue(true, for: characteristic)
                }
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
        if let access = characteristicAccesses.retrieveAccess(for: characteristic),
           case let .read(continuation) = access.value {
            if case let .failure(error) = result {
                logger.debug("Characteristic read for \(characteristic.debugIdentifier) returned with error: \(error)")
            }

            access.consume()
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
        for onChange in onChangeHandlers[locator, default: [:]].values {
            guard case let .value(handler) = onChange else {
                continue
            }
            handler(data)
        }
    }

    private func receivedWriteResponse(for characteristic: CBCharacteristic, result: Result<Void, Error>) {
        guard let access = characteristicAccesses.retrieveAccess(for: characteristic),
              case let .write(continuation) = access.value else {
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

        access.consume()
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


        nonisolated func initDevice(_ device: BluetoothPeripheral) {
            self.device = device
        }

        func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
            guard let device else {
                return
            }

            let name = peripheral.name

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    device.isolatedUpdate(of: \.peripheralName, name)
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
            guard let device else {
                return
            }

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    let rssi = RSSI.intValue
                    device.isolatedUpdate(of: \.rssi, rssi)

                    let result: Result<Int, Error> = error.map { .failure($0) } ?? .success(rssi)

                    guard let rssiContinuation = device.rssiContinuation else {
                        return
                    }

                    device.rssiContinuation = nil
                    rssiContinuation.resume(with: result)
                    assert(device.rssiAccess.signal(), "Signaled rssiAccess though no one was waiting")
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            guard let device else {
                return
            }

            // this is called if ...
            // 1) The peripheral removes a service from its database.
            // 2) The peripheral adds a new service to its database.
            // 3) The peripheral adds back a previously-removed service, but at a different location in the database.

            // so a service we requested might be gone now. Or might just have changed location.
            // So, discover them to check if they moved location?

            let serviceIds = invalidatedServices.map { $0.uuid }
            logger.debug("Services modified, invalidating \(serviceIds)")

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    // update our local model!
                    device.invalidateServices(Set(serviceIds))

                    // make sure we try to rediscover those services though
                    peripheral.discoverServices(serviceIds)
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            guard let device else {
                return
            }

            if let error {
                logger.error("Error discovering services: \(error.localizedDescription)")
                return
            }

            guard let services = peripheral.services else {
                logger.error("Discovered services but they weren't present!")
                return
            }

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    device.discovered(services: services)

                    logger.debug("Discovered \(services) services for peripheral \(device.peripheral.debugIdentifier)")

                    for service in services {
                        guard let requestedCharacteristicsDic = device.requestedCharacteristics,
                              let requestedCharacteristicsDescriptions = requestedCharacteristicsDic[service.uuid] else {
                            continue
                        }

                        let requestedCharacteristics = requestedCharacteristicsDescriptions?.map { $0.characteristicId }

                        if let requestedCharacteristics, requestedCharacteristics.isEmpty {
                            continue
                        }

                        device.servicesAwaitingCharacteristicsDiscovery.insert(service.uuid)
                        peripheral.discoverCharacteristics(requestedCharacteristics, for: service)
                    }

                    if device.servicesAwaitingCharacteristicsDiscovery.isEmpty {
                        device._storage.signalFullyDiscovered()
                    }
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            guard let device else {
                return
            }

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    // update our model with latest characteristics!
                    device.synchronizeModel(for: service)

                    // ensure we keep track of all discoveries, set .connected state
                    device.servicesAwaitingCharacteristicsDiscovery.remove(service.uuid)
                    if device.servicesAwaitingCharacteristicsDiscovery.isEmpty {
                        device._storage.signalFullyDiscovered()
                    }

                    if let error {
                        logger.error("Error discovering characteristics: \(error.localizedDescription)")
                        return
                    }

                    // handle auto-subscribe and discover descriptors
                    device.discovered(service: service)
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }

            guard let descriptors = characteristic.descriptors else {
                return
            }

            logger.debug("Discovered descriptors for characteristic \(characteristic.debugIdentifier): \(descriptors)")

            let capture = CBCharacteristicCapture(from: characteristic)

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    device.synchronizeModel(for: characteristic, capture: capture)
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }

            let capture = CBCharacteristicCapture(from: characteristic)

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    // make sure value is propagated beforehand
                    device.synchronizeModel(for: characteristic, capture: capture)

                    if let error {
                        device.receivedUpdatedValue(for: characteristic, result: .failure(error))
                    } else if let value = capture.value {
                        device.receivedUpdatedValue(for: characteristic, result: .success(value))
                    }
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }

            let capture = CBCharacteristicCapture(from: characteristic)

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    device.synchronizeModel(for: characteristic, capture: capture)

                    let result: Result<Void, Error> = error.map { .failure($0) } ?? .success(())
                    device.receivedWriteResponse(for: characteristic, result: result)
                }
            }
        }

        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            guard let device else {
                return
            }

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    guard let writeWithoutResponseContinuation = device.writeWithoutResponseContinuation else {
                        return
                    }

                    device.writeWithoutResponseContinuation = nil
                    writeWithoutResponseContinuation.resume()
                    assert(device.writeWithoutResponseAccess.signal(), "Signaled writeWithoutResponseAccess though no one was waiting")
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            guard let device else {
                return
            }

            if let error = error {
                logger.error("Error changing notification state for \(characteristic.uuid): \(error)")
                return
            }

            let capture = CBCharacteristicCapture(from: characteristic)

            Task { @SpeziBluetooth in
                await device.isolated { device in
                    device.synchronizeModel(for: characteristic, capture: capture)

                    if capture.isNotifying {
                        logger.log("Notification began on \(characteristic.debugIdentifier)")
                    } else {
                        logger.log("Notification stopped on \(characteristic.debugIdentifier).")
                    }
                }
            }
        }
    }
} // swiftlint:disable:this file_length
