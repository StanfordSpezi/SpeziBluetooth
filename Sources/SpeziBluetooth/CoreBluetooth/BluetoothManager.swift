//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import CoreBluetooth
import NIO
import Observation
import OrderedCollections
import OSLog


/// Connect and communicate with Bluetooth devices.
///
/// This module allows to connect and communicate with Bluetooth devices using modern programming paradigms.
/// Under the hood this module uses Apple's [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth).
///
/// ### Configure the Bluetooth Manager
///
/// To configure the Bluetooth Manager, you need to specify what devices you want to discover and what services and
/// characteristics you are interested in.
/// To do so, provide a set of ``DiscoveryDescription``s upon initialization of the `BluetoothManager`.
///
/// Below is a short code example to discover devices with a Heart Rate service.
///
/// ```swift
/// let manager = BluetoothManager()
///
/// manager.scanNearbyDevices(discovery: devices [
///     DeviceDescription(discoverBy: .advertisedService("180D"), services: [
///         ServiceDescription(serviceId: "180D", characteristics: [
///             "2A37", // heart rate measurement
///             "2A38", // body sensor location
///             "2A39" // heart rate control point
///         ])
///     ])
/// ])
/// // ...
/// manager.stopScanning()
/// ```
///
/// ### Searching for nearby devices
///
/// You can scan for nearby devices using the ``scanNearbyDevices(discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)`` and stop scanning with ``stopScanning()``.
/// All discovered peripherals will be populated through the ``nearbyPeripherals`` properties.
///
/// Refer to the documentation of ``BluetoothPeripheral`` on how to interact with a Bluetooth peripheral.
///
/// - Tip: You can also use the ``SwiftUI/View/scanNearbyDevices(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``
///     and ``SwiftUI/View/autoConnect(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:)``
///     modifiers within your SwiftUI view to automatically manage device scanning and/or auto connect to the
///     first available device.
///
/// ## Topics
///
/// ### Create a Bluetooth Manager
///
/// - ``init()``
///
/// ### Bluetooth State
///
/// - ``state``
/// - ``isScanning``
/// - ``stateSubscription``
///
/// ### Discovering nearby Peripherals
/// - ``nearbyPeripherals``
/// - ``scanNearbyDevices(discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``
/// - ``stopScanning()``
///
/// ### Retrieving known Peripherals
/// - ``retrievePeripheral(for:with:)``
///
/// ### Manually Manage Powered State
/// - ``powerOn()``
/// - ``powerOff()``
public actor BluetoothManager: Observable, BluetoothActor { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    /// The serial executor for all Bluetooth related functionality.
    let bluetoothQueue: DispatchSerialQueue

    @Lazy private var centralManager: CBCentralManager
    private var centralDelegate: Delegate?
    private var isScanningObserver: KVOStateObserver<BluetoothManager>?

    private let _storage: ObservableStorage
    private var isolatedStorage: ObservableStorage {
        _storage
    }

    /// Flag indicating that we want the CBCentral to stay allocated.
    private var keepPoweredOn = false

    /// Currently ongoing discovery session.
    private var discoverySession: DiscoverySession?

    /// The list of nearby bluetooth devices.
    ///
    /// This array contains all discovered bluetooth peripherals and those with which we are currently connected.
    nonisolated public var nearbyPeripherals: [BluetoothPeripheral] {
        Array(_storage.discoveredPeripherals.values)
    }

    /// Represents the current state of the Bluetooth Manager.
    nonisolated public var state: BluetoothState {
        _storage.state
    }

    /// Subscribe to changes of the `state` property.
    ///
    /// Creates an `AsyncStream` that yields all **future** changes to the ``state`` property.
    public var stateSubscription: AsyncStream<BluetoothState> {
        AsyncStream(BluetoothState.self) { continuation in
            let id = isolatedStorage.subscribe(continuation)
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self = self else {
                    return
                }
                Task.detached { @SpeziBluetooth in
                    await self.isolatedStorage.unsubscribe(for: id)
                }
            }
        }
    }

    /// Whether or not we are currently scanning for nearby devices.
    nonisolated public var isScanning: Bool {
        _storage.isScanning
    }

    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    /// The state is isolated to our `dispatchQueue`.
    private(set) var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        get {
            isolatedStorage.discoveredPeripherals
        }
        _modify {
            yield &isolatedStorage.discoveredPeripherals
        }
        set {
            isolatedStorage.discoveredPeripherals = newValue
        }
    }

    private(set) var retrievedPeripherals: OrderedDictionary<UUID, WeakReference<BluetoothPeripheral>> {
        get {
            isolatedStorage.retrievedPeripherals
        }
        _modify {
            yield &isolatedStorage.retrievedPeripherals
        }
        set {
            isolatedStorage.retrievedPeripherals = newValue
        }
    }

    /// The combined collection of `discoveredPeripherals` and `retrievedPeripherals`.
    ///
    /// Don't store this dictionary as this will accidentally reference retrieved peripherals strongly.
    var knownPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        let keysAndValues = retrievedPeripherals.elements
            .map { ($0, $1.value) }
            .compactMap { id, value in
                if let value {
                    return (id, value)
                }
                return nil
            }

        return discoveredPeripherals.merging(keysAndValues) { lhs, rhs in
            assertionFailure("Peripheral was present in both, discovered and retrieved set, lhs: \(lhs), rhs: \(rhs)")
            return lhs
        }
    }

    
    /// Initialize a new Bluetooth Manager with provided device description and optional configuration options.
    public init() {
        let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)
        guard let serialQueue = dispatchQueue as? DispatchSerialQueue else {
            preconditionFailure("Dispatch queue \(dispatchQueue.label) was not initialized to be serial!")
        }

        self.bluetoothQueue = serialQueue

        self._storage = ObservableStorage()

        let delegate = Delegate()
        self.centralDelegate = delegate
        self._centralManager = Lazy()

        // The Bluetooth permission alert shows every time when a CBCentralManager is initialized.
        // If we already have permissions the a power alert will be shown if the user has Bluetooth disabled.
        // To have those alerts shown at the right time (and repeatedly), we lazily initialize the CBCentralManager and also deinit it
        // once we don't use it anymore (we are not scanning and no device is currently connected).
        // All this state handling happens here within the closures passed to the `Lazy` property wrapper.
        _centralManager.supply { [weak self] in
            // As `centralManager` is actor isolated, the initializer closure and the onCleanup closure
            // can both be assumed to be isolated to the BluetoothManager.
            let centralDelegate = self?.assumeIsolated { $0.centralDelegate }
            let central = CBCentralManager(
                delegate: centralDelegate,
                queue: serialQueue,
                options: [CBCentralManagerOptionShowPowerAlertKey: true]
            )

            self?.assumeIsolated { manager in
                manager.isScanningObserver = KVOStateObserver(receiver: manager, entity: central, property: \.isScanning)
            }

            self?.logger.debug("Initialized the underlying CBCentralManager.")
            return central
        } onCleanup: { [weak self] in
            self?.logger.debug("Destroyed the underlying CBCentralManager.")
            self?.assumeIsolated { manager in
                manager.isScanningObserver = nil
            }
        }

        // delay using self so we don't leave isolation
        delegate.initManager(self)
    }

    /// Request to power up the Bluetooth Central.
    ///
    /// This method manually instantiates the underlying Central Manager and ensure that it stays allocated.
    /// Balance this call with a call to ``powerOff()``.
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission prompts to the latest possible moment avoiding to unexpectedly display power alerts.
    public func powerOn() {
        keepPoweredOn = true
        _ = centralManager // ensure it is allocated
    }

    /// Request to power down the Bluetooth Central.
    ///
    /// This method request to power off the central. This is delay if the central is still used (e.g., currently scanning or connected peripherals).
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission prompts to the latest possible moment avoiding to unexpectedly display power alerts.
    public func powerOff() {
        keepPoweredOn = false
        checkForCentralDeinit()
    }

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``DiscoveryDescription`` provided in the initializer.
    /// All discovered devices can be accessed through the ``nearbyPeripherals`` property.
    ///
    /// - Tip: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameters:
    ///   - discovery: The set of device description describing **how** and **what** to discover.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    public func scanNearbyDevices(
        discovery: Set<DiscoveryDescription>,
        minimumRSSI: Int? = nil,
        advertisementStaleInterval: TimeInterval? = nil,
        autoConnect: Bool = false
    ) {
        let state = BluetoothManagerDiscoveryState(
            configuredDevices: discovery,
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval,
            autoConnect: autoConnect
        )
        scanNearbyDevices(state)
    }

    func scanNearbyDevices(_ state: BluetoothManagerDiscoveryState) {
        guard discoverySession == nil else {
            return // already scanning!
        }

        logger.debug("Creating discovery session ...")

        let session = DiscoverySession(
            boundTo: self,
            configuration: state
        )
        self.discoverySession = session

        // if powered of, we start scanning later in `handlePoweredOn()`
        if case .poweredOn = centralManager.state {
            _scanForPeripherals(using: session)
        }
    }

    private func _scanForPeripherals(using session: DiscoverySession) {
        guard !isScanning else {
            return
        }

        logger.debug("Starting scanning for nearby devices ...")
        centralManager.scanForPeripherals(
            withServices: session.assumeIsolated { $0.serviceDiscoveryIds },
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isolatedStorage.isScanning = centralManager.isScanning // ensure this is propagated instantly
    }

    private func _restartScanning(using session: DiscoverySession) {
        guard !isScanning else {
            return
        }

        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: session.assumeIsolated { $0.serviceDiscoveryIds },
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isolatedStorage.isScanning = centralManager.isScanning // ensure this is propagated instantly
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() {
        if isScanning { // transitively checks for state == .poweredOn
            centralManager.stopScan()
            isolatedStorage.isScanning = centralManager.isScanning // ensure this is synced
            logger.debug("Scanning stopped")
        }

        if discoverySession != nil {
            logger.debug("Discovery session cleared.")
            discoverySession = nil
            checkForCentralDeinit()
        }
    }


    /// Reactive scan upon powered on.
    private func handlePoweredOn() {
        if let discoverySession, !isScanning {
            _scanForPeripherals(using: discoverySession)
        }
    }

    private func handleStoppedScanning() {
        let devices = discoveredPeripherals.values.filter { device in
            device.cbPeripheral.state == .disconnected
        }

        for device in devices {
            clearDiscoveredPeripheral(forKey: device.id)
        }

        if devices.isEmpty { // otherwise deinit was already called
            checkForCentralDeinit()
        }
    }


    /// Retrieve a known `BluetoothPeripheral` by its identifier.
    ///
    /// This method queries the list of known ``BluetoothPeripheral``s (e.g., paired peripherals).
    ///
    /// - Tip: You can use this method to connect to a known peripheral. Retrieve the peripheral using this method and call the ``BluetoothPeripheral/connect()`` method.
    ///     The `connect()` method doesn't time out and will make sure to connect to the peripheral once it is available without the need for continuous scanning.
    ///
    /// - Important: Make sure to keep a strong reference to the returned peripheral. The `BluetoothManager` only keeps a weak reference to the peripheral.
    ///     If you don't need the peripheral anymore, ``BluetoothPeripheral/disconnect()`` and dereference it.
    ///
    /// - Parameters:
    ///   - uuid: The Bluetooth peripheral identifier.
    ///   - description: The expected device configuration of the peripheral. This is used to discover service and characteristics if you connect to the peripheral-
    /// - Returns: The retrieved Peripheral. Returns nil if the Bluetooth Central could not be powered on (e.g., not authorized) or if no peripheral with the requested identifier was found.
    public func retrievePeripheral(for uuid: UUID, with description: DeviceDescription) async -> BluetoothPeripheral? {
        if !_centralManager.isInitialized {
            _ = centralManager // make sure central is initialized!

            // we are waiting for the next state transition, ideally to poweredOn state!
            logger.debug("Waiting for CBCentral to power on, before retrieving peripheral.")
            for await nextState in stateSubscription {
                logger.debug("CBCentral state transitioned to state \(nextState)")
                break
            }
        }

        guard case .poweredOn = centralManager.state else {
            logger.warning("Cannot retrieve peripheral with id \(uuid) while central is not powered on \(self.state)")
            checkForCentralDeinit()
            return nil
        }

        if let peripheral = knownPeripheral(for: uuid) {
            return peripheral // peripheral was already retrieved or was recently discovered
        }

        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first else {
            checkForCentralDeinit()
            return nil
        }


        let device = BluetoothPeripheral(
            manager: self,
            peripheral: peripheral,
            configuration: description,
            advertisementData: .init([:]), // there was no advertisement
            rssi: 127 // value of 127 signifies unavailability of RSSI value
        )

        retrievedPeripherals.updateValue(WeakReference(device), forKey: peripheral.identifier)

        return device
    }

    func onChange<Value>(of keyPath: KeyPath<ObservableStorage, Value>, perform closure: @escaping (Value) -> Void) {
        _storage.onChange(of: keyPath, perform: closure)
    }

    func clearDiscoveredPeripheral(forKey id: UUID) {
        if let peripheral = discoveredPeripherals[id] {
            // `handleDiscarded` must be called before actually removing it from the dictionary to make sure peripherals can react to this event
            peripheral.assumeIsolated { device in
                device.handleDiscarded()
            }

            // Users might keep reference to Peripheral object. Therefore, we keep it as a weak reference so we can forward delegate calls.
            retrievedPeripherals[id] = WeakReference(peripheral)
        }

        discoveredPeripherals.removeValue(forKey: id)

        discoverySession?.assumeIsolated { session in
            session.clearManuallyDisconnectedDevice(for: id)
        }

        checkForCentralDeinit()
    }

    fileprivate func knownPeripheral(for uuid: UUID) -> BluetoothPeripheral? {
        if let peripheral = discoveredPeripherals[uuid] {
            return peripheral
        }

        guard let reference = retrievedPeripherals[uuid] else {
            return nil
        }

        guard let peripheral = reference.value else {
            retrievedPeripherals.removeValue(forKey: uuid)
            return nil
        }
        return peripheral
    }

    fileprivate func ensurePeripheralReference(_ peripheral: BluetoothPeripheral) {
        guard retrievedPeripherals[peripheral.id] != nil else {
            return // is not weakly referenced
        }

        retrievedPeripherals[peripheral.id] = nil
        discoveredPeripherals[peripheral.id] = peripheral
    }

    /// The peripheral was finally deallocated.
    ///
    /// This method makes sure that all (weak) references to the de-initialized peripheral are fully cleared.
    func handlePeripheralDeinit(id uuid: UUID) {
        retrievedPeripherals.removeValue(forKey: uuid)

        discoverySession?.assumeIsolated { session in
            session.clearManuallyDisconnectedDevice(for: uuid)
        }

        checkForCentralDeinit()
    }

    /// De-initializes the Bluetooth Central if we currently don't use it.
    private func checkForCentralDeinit() {
        guard !keepPoweredOn else {
            return // requested to stay allocated
        }

        guard discoverySession == nil else {
            return // discovery is currently running
        }

        guard discoveredPeripherals.isEmpty && retrievedPeripherals.isEmpty else {
            let discoveredCount = discoveredPeripherals.count
            let retrievedCount = retrievedPeripherals.count
            logger.debug("Not deallocating central. Devices are still associated: discovered: \(discoveredCount), retrieved: \(retrievedCount)")
            return // there are still associated devices
        }

        _centralManager.destroy()
        isolatedStorage.state = .unknown
    }

    func connect(peripheral: BluetoothPeripheral) {
        logger.debug("Trying to connect to \(peripheral.cbPeripheral.debugIdentifier) ...")

        let cancelled = discoverySession?.assumeIsolated { session in
            session.cancelStaleTask(for: peripheral)
        }

        self.centralManager.connect(peripheral.cbPeripheral, options: nil)

        if cancelled == true {
            discoverySession?.assumeIsolated { session in
                session.scheduleStaleTaskForOldestActivityDevice(ignore: peripheral)
            }
        }
    }

    func disconnect(peripheral: BluetoothPeripheral) {
        logger.debug("Disconnecting peripheral \(peripheral.cbPeripheral.debugIdentifier) ...")
        // stale timer is handled in the delegate method
        centralManager.cancelPeripheralConnection(peripheral.cbPeripheral)

        discoverySession?.assumeIsolated { session in
            session.deviceManuallyDisconnected(id: peripheral.id)
        }
    }

    private func handledConnected(device: BluetoothPeripheral) {
        device.assumeIsolated { device in
            device.handleConnect()
        }

        // we might have connected a bluetooth peripheral that was weakly referenced
        ensurePeripheralReference(device)
    }

    private func discardDevice(device: BluetoothPeripheral) {
        if let discoverySession, isScanning {
            // we will keep discarded devices for max 2s before the stale timer kicks off
            let backdateInterval = max(0, discoverySession.assumeIsolated { $0.advertisementStaleInterval } - 2)

            device.assumeIsolated { device in
                device.markLastActivity(.now - backdateInterval)
                device.handleDisconnect()
            }

            // We just schedule the new timer if there is a device to schedule one for.
            discoverySession.assumeIsolated { session in
                session.scheduleStaleTaskForOldestActivityDevice()
            }
        } else {
            device.assumeIsolated { device in
                device.markLastActivity()
                device.handleDisconnect()
            }
            clearDiscoveredPeripheral(forKey: device.id)
        }
    }

    deinit {
        discoverySession = nil

        // non-isolated workaround for calling stopScanning()
        if isScanning {
            _storage.isScanning = false
            _centralManager.wrappedValue.stopScan()
            logger.debug("Scanning stopped")
        }

        _storage.state = .unknown
        _storage.discoveredPeripherals = [:]
        _storage.retrievedPeripherals = [:]
        centralDelegate = nil

        logger.debug("BluetoothManager destroyed")
    }
}


extension BluetoothManager {
    @Observable
    final class ObservableStorage: ValueObservable {
        var state: BluetoothState = .unknown {
            didSet {
                _$simpleRegistrar.triggerDidChange(for: \.state, on: self)

                for continuation in subscribedContinuations.values {
                    continuation.yield(state)
                }
            }
        }
        
        var isScanning = false {
            didSet {
                _$simpleRegistrar.triggerDidChange(for: \.isScanning, on: self)
            }
        }

        var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> = [:] {
            didSet {
                _$simpleRegistrar.triggerDidChange(for: \.discoveredPeripherals, on: self)
            }
        }

        var retrievedPeripherals: OrderedDictionary<UUID, WeakReference<BluetoothPeripheral>> = [:] {
            didSet {
                _$simpleRegistrar.triggerDidChange(for: \.retrievedPeripherals, on: self)
            }
        }

        // swiftlint:disable:next identifier_name
        @ObservationIgnored var _$simpleRegistrar = ValueObservationRegistrar<BluetoothManager.ObservableStorage>()


        private var subscribedContinuations: [UUID: AsyncStream<BluetoothState>.Continuation] = [:]

        init() {}


        func subscribe(_ continuation: AsyncStream<BluetoothState>.Continuation) -> UUID {
            let id = UUID()
            subscribedContinuations[id] = continuation
            return id
        }

        func unsubscribe(for id: UUID) {
            subscribedContinuations[id] = nil
        }


        deinit {
            for continuation in subscribedContinuations.values {
                continuation.finish()
            }
            subscribedContinuations.removeAll()
        }
    }
}

extension BluetoothManager: KVOReceiver {
    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) {
        switch keyPath {
        case \CBCentralManager.isScanning:
            isolatedStorage.isScanning = value as! Bool // swiftlint:disable:this force_cast
            if !self.isScanning {
                self.handleStoppedScanning()
            }
        default:
            break
        }
    }
}


extension BluetoothManager: BluetoothScanner {
    /// Default id based on `ObjectIdentifier`.
    public nonisolated var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    /// Support for the auto connect modifier.
    @_documentation(visibility: internal)
    public nonisolated var hasConnectedDevices: Bool {
        // We make sure to loop over all peripherals here. This ensures observability subscribes to all changing states.
        // swiftlint:disable:next reduce_boolean
        _storage.discoveredPeripherals.values.reduce(into: false) { partialResult, peripheral in
            partialResult = partialResult || (peripheral.unsafeState.state != .disconnected)
        } || _storage.retrievedPeripherals.values.reduce(into: false, { partialResult, reference in
            // swiftlint:disable:previous reduce_boolean
            if let peripheral = reference.value {
                partialResult = partialResult || (peripheral.unsafeState.state != .disconnected)
            }
        })
    }

    func updateScanningState(_ state: BluetoothManagerDiscoveryState) {
        guard let discoverySession else {
            return
        }

        let discoveryItemsChanged = discoverySession.assumeIsolated { session in
            session.updateConfigurationReportingDiscoveryItemsChanged(state)
        }

        if discoveryItemsChanged == true {
            _restartScanning(using: discoverySession)
        }
    }
}


// MARK: Defaults
extension BluetoothManager {
    /// Set of default values used within the Bluetooth Manager
    enum Defaults {
        /// The default timeout after which stale advertisements are removed.
        static let defaultStaleTimeout: TimeInterval = 8
        /// The minimum rssi of a peripheral to consider it for discovery.
        static let defaultMinimumRSSI = -80
        /// The default time in seconds after which we check for auto connectable devices after the initial advertisement.
        static let defaultAutoConnectDebounce: Int = 1
    }
}


// MARK: Delegate
extension BluetoothManager {
    private class Delegate: NSObject, CBCentralManagerDelegate {
        private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManagerDelegate")

        private weak var manager: BluetoothManager?


        override init() {
            super.init()
        }

        func initManager(_ manager: BluetoothManager) {
            self.manager = manager
        }

        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            let state = BluetoothState(from: central.state)

            guard let manager else {
                return
            }

            // All these delegate methods are actually running on the DispatchQueue the Actor is isolated to.
            // So in theory we should just be able to jump into isolation with assumeIsolated().
            // However, executing a scheduled Job is different to just running a scheduled Job in the dispatch queue
            // form a Swift Runtime perspective.
            // Refer to _isCurrentExecutor (checked in assumeIsolated):
            // https://github.com/apple/swift/blob/9e2b97c0fd675efaa5b815748d8567d781415c8c/stdlib/public/Concurrency/Actor.cpp#L317
            // Also refer to te implementation of assumeIsolated:
            // https://github.com/apple/swift/blob/a1062d06e9f33512b0005d589e3b086a89cfcbd1/stdlib/public/Concurrency/ExecutorAssertions.swift#L351-L372.
            // We could just cast the closure to be isolated (nothing else does assumeIsolated), however we would not have the
            // same Runtime state as an executing Task that is actor isolated.
            // So whats the solution? We schedule onto a background SerialExecutor (@SpeziBluetooth) so we maintain execution
            // order and make sure to capture all important state before that.
            Task { @SpeziBluetooth in
                await manager.isolated { manager in
                    manager.isolatedStorage.state = state
                    logger.info("BluetoothManager central state is now \(manager.state)")

                    if case .poweredOn = state {
                        manager.handlePoweredOn()
                    } else if case .unauthorized = state {
                        switch CBCentralManager.authorization {
                        case .denied:
                            logger.log("Unauthorized reason: Access to Bluetooth was denied.")
                        case .restricted:
                            logger.log("Unauthorized reason: Bluetooth is restricted.")
                        default:
                            break
                        }
                    }
                }
            }
        }

        func centralManager(
            _ central: CBCentralManager,
            didDiscover peripheral: CBPeripheral,
            advertisementData: [String: Any],
            // We have to use NSNumber to conform to the `CBCentralManagerDelegate` delegate methods.
            // swiftlint:disable:next legacy_objc_type
            rssi: NSNumber
        ) {
            guard let manager else {
                return
            }

            Task { @SpeziBluetooth in
                await manager.isolated { manager in
                    guard let session = manager.discoverySession,
                          manager.isScanning else {
                        return
                    }

                    // ensure the signal strength is not too low
                    guard session.assumeIsolated({ $0.isInRange(rssi: rssi) }) else {
                        return // logging this would just be to verbose, so we don't.
                    }

                    let data = AdvertisementData(advertisementData)


                    // check if we already seen this device!
                    if let device = manager.knownPeripheral(for: peripheral.identifier) {
                        device.assumeIsolated { device in
                            device.markLastActivity()
                            device.update(advertisement: data, rssi: rssi.intValue)
                        }

                        // we might have discovered a previously "retrieved" peripheral that must be strongly referenced now
                        manager.ensurePeripheralReference(device)

                        session.assumeIsolated { session in
                            session.deviceDiscoveryPostAction(device: device, newlyDiscovered: false)
                        }
                        return
                    }

                    logger.debug("Discovered peripheral \(peripheral.debugIdentifier) at \(rssi.intValue) dB (data: \(advertisementData))")

                    let descriptor = session.assumeIsolated { $0.configuredDevices }
                        .find(for: data, logger: logger)
                    let device = BluetoothPeripheral(
                        manager: manager,
                        peripheral: peripheral,
                        configuration: descriptor?.device ?? DeviceDescription(),
                        advertisementData: data,
                        rssi: rssi.intValue
                    )
                    // save local-copy, such CB doesn't deallocate it
                    manager.discoveredPeripherals.updateValue(device, forKey: peripheral.identifier)


                    session.assumeIsolated { session in
                        session.deviceDiscoveryPostAction(device: device, newlyDiscovered: true)
                    }
                }
            }
        }

        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            guard let manager else {
                return
            }

            Task { @SpeziBluetooth in
                await manager.isolated { manager in
                    guard let device = manager.knownPeripheral(for: peripheral.identifier) else {
                        logger.error("Received didConnect for unknown peripheral \(peripheral.debugIdentifier). Cancelling connection ...")
                        manager.centralManager.cancelPeripheralConnection(peripheral)
                        return
                    }

                    logger.debug("Peripheral \(peripheral.debugIdentifier) connected.")
                    manager.handledConnected(device: device)
                }
            }
        }

        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            // Documentation reads: "Because connection attempts don’t time out, a failed connection usually indicates a transient issue,
            // in which case you may attempt connecting to the peripheral again."

            Task { @SpeziBluetooth in
                await manager.isolated { manager in
                    guard let device = manager.knownPeripheral(for: peripheral.identifier) else {
                        logger.warning("Unknown peripheral \(peripheral.debugIdentifier) failed with error: \(String(describing: error))")
                        manager.centralManager.cancelPeripheralConnection(peripheral)
                        return
                    }

                    if let error {
                        logger.error("Failed to connect to \(peripheral): \(error)")
                    } else {
                        logger.error("Failed to connect to \(peripheral)")
                    }

                    // just to make sure
                    manager.centralManager.cancelPeripheralConnection(device.cbPeripheral)

                    manager.discardDevice(device: device)
                }
            }
        }


        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            Task { @SpeziBluetooth in
                await manager.isolated { manager in
                    guard let device = manager.knownPeripheral(for: peripheral.identifier) else {
                        logger.error("Received didDisconnect for unknown peripheral \(peripheral.debugIdentifier).")
                        return
                    }

                    if let error {
                        logger.debug("Peripheral \(peripheral.debugIdentifier) disconnected due to an error: \(error)")
                    } else {
                        logger.debug("Peripheral \(peripheral.debugIdentifier) disconnected.")
                    }

                    manager.discardDevice(device: device)
                }
            }
        }
    }
}

// swiftlint:disable:this file_length
