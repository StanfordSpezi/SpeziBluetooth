//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

// TODO: there should be a article on the Thread-model!


import CoreBluetooth
import NIO
import Observation
import OrderedCollections
import OSLog


protocol AnyObservation {}

// TODO: calling that ValueObservation/ValueObservable!
struct SimpleObservationRegistrar<Observable: SimpleObservable> {
    struct Observation<Value>: AnyObservation {
        let keyPath: KeyPath<Observable, Value>
        let handler: (Value) -> Void
    }

    private var id: UInt64 = 0
    private var observations: [UInt64: AnyObservation] = [:]
    private var keyPathIndex: [AnyKeyPath: Set<UInt64>] = [:]

    private mutating func nextId() -> UInt64 {
        defer {
            id &+= 1 // add with overflow operator
        }
        return id
    }

    mutating func onChange<Value>(of keyPath: KeyPath<Observable, Value>, perform closure: @escaping (Value) -> Void) {
        let id = nextId()
        observations[id] = Observation(keyPath: keyPath, handler: closure)
        keyPathIndex[keyPath, default: []].insert(id)
    }

    mutating func triggerDidChange<Value>(for keyPath: KeyPath<Observable, Value>, on observable: Observable) {
        guard let ids = keyPathIndex.removeValue(forKey: keyPath) else {
            return
        }

        for id in ids {
            guard let anyObservation = observations.removeValue(forKey: id),
                  let observation = anyObservation as? Observation<Value> else {
                continue
            }

            let value = observable[keyPath: keyPath]
            observation.handler(value)
        }
    }
}

// TODO: move
protocol SimpleObservable: AnyObject {
    var _$simpleRegistrar: SimpleObservationRegistrar<Self> { get set }

    func onChange<Value>(of keyPath: KeyPath<Self, Value>, perform closure: @escaping (Value) -> Void)
}

extension SimpleObservable {
    func onChange<Value>(of keyPath: KeyPath<Self, Value>, perform closure: @escaping (Value) -> Void) {
        _$simpleRegistrar.onChange(of: keyPath, perform: closure)
    }
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
/// To do so, provide a set of ``DeviceDescription``s upon initialization of the `BluetoothManager`.
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
/// All discovered peripherals will be populated through the ``nearbyPeripherals`` or ``nearbyPeripheralsView`` properties.
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
/// - ``nearbyPeripheralsView``
/// - ``scanNearbyDevices(autoConnect:)``
/// - ``stopScanning()``
public actor BluetoothManager: Observable { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")

    /// The serial executor for all Bluetooth related functionality.
    let bluetoothExecutor: BluetoothSerialExecutor

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        bluetoothExecutor.asUnownedSerialExecutor()
    }

    @Observable
    class State: SimpleObservable {
        // TODO: naming!
        // TODO: retrieve a struct from that?
        var state: BluetoothState = .unknown
        var isScanning = false
        var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> = [:] {
            didSet {
                _$simpleRegistrar.triggerDidChange(for: \.discoveredPeripherals, on: self)
            }
        }

        // TODO: support all the other properties just for fun?
        @ObservationIgnored var _$simpleRegistrar = SimpleObservationRegistrar<BluetoothManager.State>()

        init() {}
    }


    /// The device descriptions describing how nearby devices are discovered.
    private let configuredDevices: Set<DeviceDescription>
    /// The minimum rssi that is required for a device to be discovered.
    private let minimumRSSI: Int
    /// The time interval after which an advertisement is considered stale and the device is removed.
    private let advertisementStaleInterval: TimeInterval

    @Lazy private var centralManager: CBCentralManager
    private var centralDelegate: Delegate? // swiftlint:disable:this weak_delegate
    private var isScanningObserver: KVOStateObserver<BluetoothManager>?

    private let stateContainer: State

    /// Represents the current state of the Bluetooth Manager.
    public private(set) var state: BluetoothState {
        get {
            stateContainer.state
        }
        set {
            stateContainer.state = newValue
        }
    }
    /// Whether or not we are currently scanning for nearby devices.
    public private(set) var isScanning: Bool {
        get {
            stateContainer.isScanning
        }
        set {
            stateContainer.isScanning = newValue
        }
    }
    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    /// The state is isolated to our `dispatchQueue`.
    var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        get {
            stateContainer.discoveredPeripherals
        }
        _modify {
            yield &stateContainer.discoveredPeripherals
        }
        set {
            stateContainer.discoveredPeripherals = newValue
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
                // TODO: this doesn't work yet!completeServiceDiscovery
                lhs.assumeIsolated { $0.rssi } < rhs.assumeIsolated { $0.rssi }
            }

        return sortedCandidates.first
    }

    /// The list of nearby bluetooth devices.
    ///
    /// This array contains all discovered bluetooth peripherals and those with which we are currently connected.
    public var nearbyPeripherals: [BluetoothPeripheral] {
        Array(discoveredPeripherals.values)
    }

    /// The list of nearby bluetooth devices as a view.
    ///
    /// This is similar to the ``nearbyPeripherals``. However, it doesn't copy all elements into its own array
    /// but exposes the `Values` type of the underlying Dictionary implementation.
    public var nearbyPeripheralsView: OrderedDictionary<UUID, BluetoothPeripheral>.Values {
        discoveredPeripherals.values
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
    ///   - devices: The set of device description describing **how** to discover **what** to discover.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    public init(
        devices: Set<DeviceDescription>,
        minimumRSSI: Int = Defaults.defaultMinimumRSSI,
        advertisementStaleInterval: TimeInterval = Defaults.defaultStaleTimeout
    ) {
        let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)
        /*
         /// The dispatch queue for all Bluetooth related functionality. This is serial (not `.concurrent`) to ensure synchronization.
         private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated) // TODO: access level?
         */

        self.bluetoothExecutor = BluetoothSerialExecutor(dispatchQueue: dispatchQueue)

        self.configuredDevices = devices
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = max(1, advertisementStaleInterval)

        self.stateContainer = State()

        let delegate = Delegate()
        self.centralDelegate = delegate
        self._centralManager = Lazy()

        // This helps us later to identity that we are running within the bluetooth dispatch queue!
        // TODO: self.dispatchQueue.setSpecific(key: isRunningBluetoothQueueKey, value: IsRunningBluetoothQueue())

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
                queue: dispatchQueue,
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
    /// Scans on nearby devices based on the ``DeviceDescription`` provided in the initializer.
    /// All discovered devices can be accessed through the ``nearbyPeripherals`` or ``nearbyPeripheralsView`` property.
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

    func onChange<Value>(of keyPath: KeyPath<State, Value>, perform closure: @escaping (Value) -> Void) {
        stateContainer.onChange(of: keyPath, perform: closure)
    }

    /// Reactive scan upon powered on.
    private func handlePoweredOn() {
        if shouldBeScanning && !isScanning {
            scanNearbyDevices(autoConnect: autoConnect)
        }
    }

    private func handleStoppedScanning() {
        self.autoConnect = false

        let devices = nearbyPeripheralsView.filter { device in
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
        discoveredPeripherals.removeValue(forKey: id)

        if lastManuallyDisconnectedDevice == id {
            lastManuallyDisconnectedDevice = nil
        }

        checkForCentralDeinit()
    }

    /// De-initializes the Bluetooth Central if we currently don't use it.
    private func checkForCentralDeinit() {
        if !shouldBeScanning && discoveredPeripherals.isEmpty {
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

    func findDeviceDescription(for advertisementData: AdvertisementData) -> DeviceDescription? {
        configuredDevices.find(for: advertisementData, logger: logger)
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
        bluetoothExecutor.schedule(for: .now() + .seconds(Defaults.defaultAutoConnectDebounce), execute: item)
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
        timer.schedule(for: timeout, in: bluetoothExecutor)
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
        return nearbyPeripheralsView
            // it's important to access the underlying state here
            .filter { $0.cbPeripheral.state == .disconnected && $0.id != device?.id }
            .min { lhs, rhs in
                lhs.assumeIsolated { $0.lastActivity } < rhs.assumeIsolated { $0.lastActivity }
            }
    }

    private func handleStaleTask() {
        staleTimer = nil // reset the timer

        let staleDevices = nearbyPeripheralsView.filter { device in
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
            // we will keep discarded devices for 500ms before the stale timer kicks off
            let interval = max(0, advertisementStaleInterval - 0.5)

            device.assumeIsolated { device in
                device.markLastActivity(.now - interval)
                device.handleDisconnect()
            }

            // We just schedule the new timer if there is a device to schedule one for.
            scheduleStaleTaskForOldestActivityDevice()
        }
    }


    deinit {
        // we must do it blocking to not lose reference to self.
        bluetoothExecutor.unsafeDispatchQueue.sync {
            self.assumeIsolated { manager in
                manager.stopScanning()
                manager.staleTimer?.cancel()
                manager.autoConnectItem?.cancel()

                manager.state = .unknown

                manager.discoveredPeripherals = [:]
                manager.centralDelegate = nil

                manager.logger.debug("BluetoothManager destroyed")
            }
        }
    }
}


extension BluetoothManager: KVOReceiver {
    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) {
        switch keyPath {
        case \CBCentralManager.isScanning:
            self.isScanning = value as! Bool // swiftlint:disable:this force_cast
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
        // TODO: check how we can have unsafe access?
        // TODO: no contains check but loop through all peripherals to have observability of all devices?
        stateContainer.discoveredPeripherals.values.reduce(into: false) { partialResult, peripheral in
            partialResult = partialResult || (peripheral.unsafeState.state != .disconnected)
        }
    }
}


// MARK: Defaults
extension BluetoothManager {
    /// Set of default values used within the Bluetooth Manager
    public enum Defaults {
        /// The default timeout after which stale advertisements are removed.
        public static let defaultStaleTimeout: TimeInterval = 6
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
            guard let manager else {
                return
            }

            manager.assumeIsolated { manager in
                manager.state = BluetoothState(from: central.state)
                logger.info("BluetoothManager central state is now \(manager.state)")

                if case .poweredOn = manager.state {
                    manager.handlePoweredOn()
                } else if case .unauthorized = manager.state {
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

            manager.assumeIsolated { manager in
                guard manager.isScanning else {
                    return
                }

                // rssi of 127 is a magic value signifying unavailability of the value.
                guard rssi.intValue >= manager.minimumRSSI, rssi.intValue != 127 else { // ensure the signal strength is not too low
                    return // logging this would just be to verbose, so we don't.
                }

                let data = AdvertisementData(advertisementData: advertisementData)


                // check if we already seen this device!
                if let device = manager.discoveredPeripherals[peripheral.identifier] {
                    device.assumeIsolated { device in
                        device.markLastActivity()
                        device.update(advertisement: data, rssi: rssi.intValue)
                    }
                    // TODO: check there aren't any Tasks created for device access!!

                    if manager.cancelStaleTask(for: device) {
                        // current device was earliest to go stale, schedule timeout for next oldest device
                        manager.scheduleStaleTaskForOldestActivityDevice()
                    }

                    manager.kickOffAutoConnect()
                    return
                }

                logger.debug("Discovered peripheral \(peripheral.debugIdentifier) at \(rssi.intValue) dB (data: \(advertisementData))")

                let device = BluetoothPeripheral(
                    manager: manager,
                    executor: manager.bluetoothExecutor,
                    peripheral: peripheral,
                    advertisementData: data,
                    rssi: rssi.intValue
                )
                manager.discoveredPeripherals[peripheral.identifier] = device // save local-copy, such CB doesn't deallocate it


                if manager.staleTimer == nil {
                    // There is no stale timer running. So new device will be the one with the oldest activity. Schedule ...
                    manager.scheduleStaleTask(for: device, withTimeout: manager.advertisementStaleInterval)
                }

                manager.kickOffAutoConnect()
            }
        }

        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            guard let manager else {
                return
            }

            manager.assumeIsolated { manager in
                guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
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

        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            // Documentation reads: "Because connection attempts don’t time out, a failed connection usually indicates a transient issue,
            // in which case you may attempt connecting to the peripheral again."

            manager.assumeIsolated { manager in
                guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
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


        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            manager.assumeIsolated { manager in
                guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
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
} // swiftlint:disable:this file_length
