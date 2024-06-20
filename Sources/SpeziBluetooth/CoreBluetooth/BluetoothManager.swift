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


private class DiscoverySession { // TODO: do we wanna tackle that?
}


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
/// let manager = BluetoothManager(devices [
///     DeviceDescription(discoverBy: .advertisedService("180D"), services: [
///         ServiceDescription(serviceId: "180D", characteristics: [
///             "2A37", // heart rate measurement
///             "2A38", // body sensor location
///             "2A39" // heart rate control point
///         ])
///     ])
/// ])
///
/// manager.scanNearbyDevices()
/// // ...
/// manager.stopScanning()
/// ```
///
/// ### Searching for nearby devices
///
/// You can scan for nearby devices using the ``scanNearbyDevices(autoConnect:)`` and stop scanning with ``stopScanning()``.
/// All discovered peripherals will be populated through the ``nearbyPeripherals`` properties.
///
/// Refer to the documentation of ``BluetoothPeripheral`` on how to interact with a Bluetooth peripheral.
///
/// - Tip: You can also use the ``SwiftUI/View/scanNearbyDevices(enabled:with:autoConnect:)`` and ``SwiftUI/View/autoConnect(enabled:with:)``
///     modifiers within your SwiftUI view to automatically manage device scanning and/or auto connect to the
///     first available device.
///
/// ## Topics
///
/// ### Create a Bluetooth Manager
///
/// - ``init(devices:minimumRSSI:advertisementStaleInterval:)``
///
/// ### Bluetooth State
///
/// - ``state``
/// - ``isScanning``
///
/// ### Discovering nearby Peripherals
/// - ``nearbyPeripherals``
/// - ``scanNearbyDevices(autoConnect:)``
/// - ``stopScanning()``
public actor BluetoothManager: Observable, BluetoothActor { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    /// The serial executor for all Bluetooth related functionality.
    let bluetoothQueue: DispatchSerialQueue


    /// The device descriptions describing how nearby devices are discovered.
    private let configuredDevices: Set<DiscoveryDescription> // TODO: these are all considered for "DiscoverySession"!
    /// The minimum rssi that is required for a device to be discovered.
    private let minimumRSSI: Int
    /// The time interval after which an advertisement is considered stale and the device is removed.
    private let advertisementStaleInterval: TimeInterval

    @Lazy private var centralManager: CBCentralManager
    private var centralDelegate: Delegate?
    private var isScanningObserver: KVOStateObserver<BluetoothManager>?

    private let _storage: ObservableStorage

    /// Represents the current state of the Bluetooth Manager.
    nonisolated public private(set) var state: BluetoothState {
        get {
            _storage.state
        }
        set {
            _storage.state = newValue
        }
    }
    /// Whether or not we are currently scanning for nearby devices.
    nonisolated public private(set) var isScanning: Bool {
        get {
            _storage.isScanning
        }
        set {
            _storage.isScanning = newValue
        }
    }
    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    /// The state is isolated to our `dispatchQueue`.
    private(set) var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        get {
            _storage.discoveredPeripherals
        }
        /* TODO: reenable!
        _modify {
            yield &_storage.discoveredPeripherals
        }
    */
        set {
            _storage.discoveredPeripherals = newValue
        }
    }

    private(set) var retrievedPeripherals: OrderedDictionary<UUID, WeakReference<BluetoothPeripheral>> {
        get {
            _storage.retrievedPeripherals
        }
        // TODO: support modify?
        set {
            _storage.retrievedPeripherals = newValue
        }
    }

    /// Track if we should be scanning. This is important to check which resources should stay allocated.
    private var shouldBeScanning = false
    /// The identifier of the last manually disconnected device.
    /// This is to avoid automatically reconnecting to a device that was manually disconnected.
    private var lastManuallyDisconnectedDevice: UUID?

    private var autoConnect = false
    private var autoConnectItem: BluetoothWorkItem?
    private var staleTimer: DiscoveryStaleTimer?

    /// Checks and determines the device candidate for auto-connect.
    ///
    /// This will deliver a matching candidate with the lowest RSSI if we don't have a device already connected,
    /// and there wasn't a device manually disconnected.
    private var autoConnectDeviceCandidate: BluetoothPeripheral? {
        guard autoConnect else {
            return nil // auto-connect is disabled
        }

        guard lastManuallyDisconnectedDevice == nil && !hasConnectedDevices else {
            return nil
        }

        let sortedCandidates = discoveredPeripherals.values
            .filter { $0.cbPeripheral.state == .disconnected }
            .sorted { lhs, rhs in
                lhs.assumeIsolated { $0.rssi } < rhs.assumeIsolated { $0.rssi }
            }

        return sortedCandidates.first
    }

    /// The list of nearby bluetooth devices.
    ///
    /// This array contains all discovered bluetooth peripherals and those with which we are currently connected.
    nonisolated public var nearbyPeripherals: [BluetoothPeripheral] {
        Array(_storage.discoveredPeripherals.values)
    }

    /// The set of serviceIds we request to discover upon scanning.
    /// Returning nil means scanning for all peripherals.
    private var serviceDiscoveryIds: [CBUUID]? { // swiftlint:disable:this discouraged_optional_collection
        let discoveryIds = configuredDevices.compactMap { configuration in
            configuration.discoveryCriteria.discoveryId
        }

        return discoveryIds.isEmpty ? nil : discoveryIds
    }

    
    /// Initialize a new Bluetooth Manager with provided device description and optional configuration options.
    /// - Parameters:
    ///   - discovery: The set of device description describing **how** to discover **what** to discover.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    public init(
        discovery: Set<DiscoveryDescription>,
        minimumRSSI: Int = Defaults.defaultMinimumRSSI,
        advertisementStaleInterval: TimeInterval = Defaults.defaultStaleTimeout
    ) {
        let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)
        guard let serialQueue = dispatchQueue as? DispatchSerialQueue else {
            preconditionFailure("Dispatch queue \(dispatchQueue.label) was not initialized to be serial!")
        }

        self.bluetoothQueue = serialQueue

        self.configuredDevices = discovery
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = max(1, advertisementStaleInterval)

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

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``DiscoveryDescription`` provided in the initializer.
    /// All discovered devices can be accessed through the ``nearbyPeripherals`` property.
    ///
    /// - Tip: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(enabled:with:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameter autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    public func scanNearbyDevices(autoConnect: Bool = false) {
        guard !isScanning else {
            return
        }

        logger.debug("Starting scanning for nearby devices ...")

        shouldBeScanning = true
        self.autoConnect = autoConnect

        // using shouldBeScanning we listen for central to power on if it isn't already
        if case .poweredOn = centralManager.state {
            centralManager.scanForPeripherals(
                withServices: serviceDiscoveryIds,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            isScanning = centralManager.isScanning // ensure this is propagated instantly
        }
    }

    /// If scanning, toggle the auto-connect feature.
    /// - Parameter autoConnect: Flag to turn on or off auto-connect
    @_documentation(visibility: internal)
    public func setAutoConnect(_ autoConnect: Bool) {
        if self.shouldBeScanning {
            self.autoConnect = autoConnect
        }
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() {
        if isScanning { // transitively checks for state == .poweredOn
            centralManager.stopScan()
            isScanning = centralManager.isScanning // ensure this is synced
            logger.debug("Scanning stopped")
        }

        if shouldBeScanning {
            shouldBeScanning = false
            checkForCentralDeinit()
        }
    }


    // TODO: docs: weak reference semantics!
    public func retrievePeripheral(for uuid: UUID, with description: DeviceDescription) async -> BluetoothPeripheral? {
        // TODO: only works if state is powered on => await poweredOn!

        // TODO: how should API users generally await for poweredOn state? => Module Events?
        await awaitCentralPoweredOn()

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
            advertisementData: .init(advertisementData: [:]), // there was no advertisement
            rssi: 127 // value of 127 signifies unavailability of RSSI value
        )

        retrievedPeripherals.updateValue(WeakReference(device), forKey: peripheral.identifier)

        return device
    }

    func knownPeripheral(for uuid: UUID) -> BluetoothPeripheral? {
        // TODO: first check for retrieved peripherals? WE MUST maintain uniqueness!
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

    func onChange<Value>(of keyPath: KeyPath<ObservableStorage, Value>, perform closure: @escaping (Value) -> Void) {
        _storage.onChange(of: keyPath, perform: closure)
    }

    /// Reactive scan upon powered on.
    private func handlePoweredOn() {
        if shouldBeScanning && !isScanning {
            scanNearbyDevices(autoConnect: autoConnect)
        }
    }

    private func handleStoppedScanning() {
        self.autoConnect = false

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

    private func clearDiscoveredPeripheral(forKey id: UUID) {
        if let peripheral = discoveredPeripherals[id] {
            // `handleDiscarded` must be called before actually removing it from the dictionary to make sure peripherals can react to this event
            peripheral.assumeIsolated { device in
                device.handleDiscarded()
            }

            // Users might keep reference to Peripheral object. Therefore, we keep it as a weak reference so we can forward delegate calls.
            retrievedPeripherals[id] = WeakReference(peripheral)
            // TODO: when does Bluetooth Module uninject stuff?
        }

        discoveredPeripherals.removeValue(forKey: id)

        if lastManuallyDisconnectedDevice == id {
            lastManuallyDisconnectedDevice = nil
        }

        checkForCentralDeinit()
    }

    func handlePeripheralDeinit(id uuid: UUID) {
        retrievedPeripherals.removeValue(forKey: uuid) // TODO: assert its the same instance?

        // TODO: also handle lastManuallyDisconnectedDevice??

        checkForCentralDeinit()
    }

    private func awaitCentralPoweredOn() async {
        _ = centralManager
        try? await Task.sleep(for: .seconds(2))

        // TODO: somehow implement!
    }

    /// De-initializes the Bluetooth Central if we currently don't use it.
    private func checkForCentralDeinit() {
        if !shouldBeScanning && discoveredPeripherals.isEmpty && retrievedPeripherals.isEmpty {
            // TODO: check for retrieved peripherals to be empty? more than that?
            _centralManager.destroy()
            self.state = .unknown
            self.lastManuallyDisconnectedDevice = nil
        }
    }

    func connect(peripheral: BluetoothPeripheral) {
        logger.debug("Trying to connect to \(peripheral.cbPeripheral.debugIdentifier) ...")

        let cancelled = self.cancelStaleTask(for: peripheral)

        self.centralManager.connect(peripheral.cbPeripheral, options: nil)

        if cancelled {
            self.scheduleStaleTaskForOldestActivityDevice(ignore: peripheral)
        }
    }

    func disconnect(peripheral: BluetoothPeripheral) {
        logger.debug("Disconnecting peripheral \(peripheral.cbPeripheral.debugIdentifier) ...")
        // stale timer is handled in the delegate method
        centralManager.cancelPeripheralConnection(peripheral.cbPeripheral)

        self.lastManuallyDisconnectedDevice = peripheral.id
    }

    // MARK: - Auto Connect

    private func kickOffAutoConnect() {
        guard autoConnectItem == nil && autoConnectDeviceCandidate != nil else {
            return
        }

        let item = BluetoothWorkItem(manager: self) { manager in
            manager.autoConnectItem = nil

            guard let candidate = manager.autoConnectDeviceCandidate else {
                return
            }

            candidate.assumeIsolated { peripheral in
                peripheral.connect()
            }
        }

        autoConnectItem = item
        bluetoothQueue.schedule(for: .now() + .seconds(Defaults.defaultAutoConnectDebounce), execute: item)
    }

    // MARK: - Stale Advertisement Timeout

    /// Schedule a new `DiscoveryStaleTimer`, cancelling any previous one.
    /// - Parameters:
    ///   - device: The device for which the timer is scheduled for.
    ///   - timeout: The timeout for which the timer is scheduled for.
    private func scheduleStaleTask(for device: BluetoothPeripheral, withTimeout timeout: TimeInterval) {
        let timer = DiscoveryStaleTimer(device: device.id, manager: self) { manager in
            manager.handleStaleTask()
        }

        self.staleTimer = timer
        timer.schedule(for: timeout, in: bluetoothQueue)
    }

    private func scheduleStaleTaskForOldestActivityDevice(ignore device: BluetoothPeripheral? = nil) {
        if let oldestActivityDevice = oldestActivityDevice(ignore: device) {
            let lastActivity = oldestActivityDevice.assumeIsolated { $0.lastActivity }

            let intervalSinceLastActivity = Date.now.timeIntervalSince(lastActivity)
            let nextTimeout = max(0, advertisementStaleInterval - intervalSinceLastActivity)

            scheduleStaleTask(for: oldestActivityDevice, withTimeout: nextTimeout)
        }
    }

    private func cancelStaleTask(for device: BluetoothPeripheral) -> Bool {
        guard let staleTimer, staleTimer.targetDevice == device.id else {
            return false
        }

        staleTimer.cancel()
        self.staleTimer = nil
        return true
    }

    /// The device with the oldest device activity.
    /// - Parameter device: The device to ignore.
    private func oldestActivityDevice(ignore device: BluetoothPeripheral? = nil) -> BluetoothPeripheral? {
        // when we are just interested in the min device, this operation is a bit cheaper then sorting the whole list
        discoveredPeripherals.values
            // it's important to access the underlying state here
            .filter {
                $0.cbPeripheral.state == .disconnected && $0.id != device?.id
            }
            .min { lhs, rhs in
                lhs.assumeIsolated {
                    $0.lastActivity
                } < rhs.assumeIsolated {
                    $0.lastActivity
                }
            }
    }

    private func handleStaleTask() {
        staleTimer = nil // reset the timer

        let staleDevices = discoveredPeripherals.values.filter { device in
            device.assumeIsolated { isolated in
                isolated.isConsideredStale(interval: advertisementStaleInterval)
            }
        }

        for device in staleDevices {
            logger.debug("Removing stale peripheral \(device.cbPeripheral.debugIdentifier)")
            // we know it won't be connected, therefore we just need to remove it
            clearDiscoveredPeripheral(forKey: device.id)
        }


        // schedule the next timeout for devices in the list
        scheduleStaleTaskForOldestActivityDevice()
    }

    private func discardDevice(device: BluetoothPeripheral) {
        if !isScanning {
            device.assumeIsolated { device in
                device.markLastActivity()
                device.handleDisconnect()
            }
            clearDiscoveredPeripheral(forKey: device.id)
        } else {
            // we will keep discarded devices for max 2s before the stale timer kicks off
            let interval = max(0, advertisementStaleInterval - 2)

            device.assumeIsolated { device in
                device.markLastActivity(.now - interval)
                device.handleDisconnect()
            }

            // We just schedule the new timer if there is a device to schedule one for.
            scheduleStaleTaskForOldestActivityDevice()
        }
    }

    private func isolatedUpdate<Value>(of keyPath: WritableKeyPath<BluetoothManager, Value>, _ value: Value) {
        var manager = self
        manager[keyPath: keyPath] = value
    }

    deinit {
        staleTimer?.cancel()
        autoConnectItem?.cancel()

        // non-isolated workaround for calling stopScanning()
        if isScanning {
            isScanning = false
            _centralManager.wrappedValue.stopScan()
            logger.debug("Scanning stopped")
        }

        state = .unknown
        _storage.discoveredPeripherals = [:]
        // TODO: also reset retrieve peripherals? doesn't make a difference!
        centralDelegate = nil

        logger.debug("BluetoothManager destroyed")
    }
}


extension BluetoothManager {
    @Observable
    class ObservableStorage: ValueObservable {
        var state: BluetoothState = .unknown {
            didSet {
                _$simpleRegistrar.triggerDidChange(for: \.state, on: self)
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

        init() {}
    }
}

extension BluetoothManager: KVOReceiver {
    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) {
        switch keyPath {
        case \CBCentralManager.isScanning:
            self.isolatedUpdate(of: \.isScanning, value as! Bool) // swiftlint:disable:this force_cast
            if !self.isScanning {
                self.handleStoppedScanning()
            }
        default:
            break
        }
    }
}


extension BluetoothManager: BluetoothScanner {
    /// Support for the auto connect modifier.
    @_documentation(visibility: internal)
    public nonisolated var hasConnectedDevices: Bool {
        // We make sure to loop over all peripherals here. This ensures observability subscribes to all changing states.
        // swiftlint:disable:next reduce_boolean
        _storage.discoveredPeripherals.values.reduce(into: false) { partialResult, peripheral in
            // TODO: also consider retrieved peripherals?
            partialResult = partialResult || (peripheral.unsafeState.state != .disconnected)
        }
    }
}


// MARK: Defaults
extension BluetoothManager {
    /// Set of default values used within the Bluetooth Manager
    public enum Defaults {
        /// The default timeout after which stale advertisements are removed.
        public static let defaultStaleTimeout: TimeInterval = 8
        /// The minimum rssi of a peripheral to consider it for discovery.
        public static let defaultMinimumRSSI = -80
        /// The default time in seconds after which we check for auto connectable devices after the initial advertisement.
        public static let defaultAutoConnectDebounce: Int = 1
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
                    manager.isolatedUpdate(of: \.state, state)
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
                    guard manager.isScanning else {
                        return
                    }

                    // rssi of 127 is a magic value signifying unavailability of the value.
                    guard rssi.intValue >= manager.minimumRSSI, rssi.intValue != 127 else { // ensure the signal strength is not too low
                        return // logging this would just be to verbose, so we don't.
                    }

                    let data = AdvertisementData(advertisementData: advertisementData)


                    // check if we already seen this device!
                    if let device = manager.knownPeripheral(for: peripheral.identifier) {
                        device.assumeIsolated { device in
                            device.markLastActivity()
                            device.update(advertisement: data, rssi: rssi.intValue)
                        }

                        if manager.cancelStaleTask(for: device) {
                            // current device was earliest to go stale, schedule timeout for next oldest device
                            manager.scheduleStaleTaskForOldestActivityDevice()
                        }

                        manager.kickOffAutoConnect()
                        return
                    }

                    logger.debug("Discovered peripheral \(peripheral.debugIdentifier) at \(rssi.intValue) dB (data: \(advertisementData))")

                    let descriptor = manager.configuredDevices.find(for: data, logger: logger)
                    let device = BluetoothPeripheral(
                        manager: manager,
                        peripheral: peripheral,
                        configuration: descriptor?.device ?? DeviceDescription(),
                        advertisementData: data,
                        rssi: rssi.intValue
                    )
                    // save local-copy, such CB doesn't deallocate it
                    manager.discoveredPeripherals.updateValue(device, forKey: peripheral.identifier)


                    if manager.staleTimer == nil {
                        // There is no stale timer running. So new device will be the one with the oldest activity. Schedule ...
                        manager.scheduleStaleTask(for: device, withTimeout: manager.advertisementStaleInterval)
                    }

                    manager.kickOffAutoConnect()
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
                    device.assumeIsolated { device in
                        device.handleConnect()
                    }
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
} // swiftlint:disable:this file_length
