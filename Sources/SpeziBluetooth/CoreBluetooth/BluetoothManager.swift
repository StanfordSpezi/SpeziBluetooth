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


struct IsRunningBluetoothQueue {
    init() {}
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
@Observable
public class BluetoothManager { // swiftlint:disable:this type_body_length
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    /// The dispatch queue for all Bluetooth related functionality. This is serial (not `.concurrent`) to ensure synchronization.
    private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)
    private let isRunningBluetoothQueueKey: DispatchSpecificKey<IsRunningBluetoothQueue>

    /// The device descriptions describing how nearby devices are discovered.
    private let configuredDevices: Set<DeviceDescription>
    /// The minimum rssi that is required for a device to be discovered.
    private let minimumRSSI: Int
    /// The time interval after which an advertisement is considered stale and the device is removed.
    private let advertisementStaleInterval: TimeInterval

    @Lazy @ObservationIgnored private var centralManager: CBCentralManager
    @ObservationIgnored private var centralDelegate: Delegate? // swiftlint:disable:this weak_delegate
    @ObservationIgnored private var isScanningObserver: KVOStateObserver<BluetoothManager>?

    /// Represents the current state of the Bluetooth Manager.
    public private(set) var state: BluetoothState
    /// Whether or not we are currently scanning for nearby devices.
    public private(set) var isScanning = false
    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    /// The state is isolated to our `dispatchQueue`.
    private(set) var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> = [:]

    /// Track if we should be scanning. This is important to check which resources should stay allocated.
    @ObservationIgnored private var shouldBeScanning = false
    /// The identifier of the last manually disconnected device.
    /// This is to avoid automatically reconnecting to a device that was manually disconnected.
    @ObservationIgnored private var lastManuallyDisconnectedDevice: UUID?

    @ObservationIgnored private var autoConnect = false
    @ObservationIgnored private var autoConnectItem: DispatchWorkItem?
    @ObservationIgnored private var staleTimer: DiscoveryStaleTimer?

    /// Checks and determines the device candidate for auto-connect.
    ///
    /// This will deliver a matching candidate with the lowest RSSI if we don't have a device already connected,
    /// and there wasn't a device manually disconnected.
    private var autoConnectDeviceCandidate: BluetoothPeripheral? {
        guard lastManuallyDisconnectedDevice == nil && !hasConnectedDevices else {
            return nil
        }

        let sortedCandidates = discoveredPeripherals.values
            .filter { $0.cbPeripheral.state == .disconnected }
            .sorted { lhs, rhs in
                lhs.rssi < rhs.rssi
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

    private var isRunningWithinQueue: Bool {
        DispatchQueue.getSpecific(key: isRunningBluetoothQueueKey) != nil
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
        self.isRunningBluetoothQueueKey = DispatchSpecificKey<IsRunningBluetoothQueue>()

        self.configuredDevices = devices
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = max(1, advertisementStaleInterval)

        self.state = .unknown

        self.centralDelegate = Delegate(self)

        // This helps us later to identity that we are running within the bluetooth dispatch queue!
        self.dispatchQueue.setSpecific(key: isRunningBluetoothQueueKey, value: IsRunningBluetoothQueue())

        // The Bluetooth permission alert shows every time when a CBCentralManager is initialized.
        // If we already have permissions the a power alert will be shown if the user has Bluetooth disabled.
        // To have those alerts shown at the right time (and repeatedly), we lazily initialize the CBCentralManager and also deinit it
        // once we don't use it anymore (we are not scanning and no device is currently connected).
        // All this state handling happens here within the closures passed to the `Lazy` property wrapper.
        _centralManager = Lazy { [weak self] in
            let central = CBCentralManager(
                delegate: self?.centralDelegate,
                queue: self?.dispatchQueue,
                options: [CBCentralManagerOptionShowPowerAlertKey: true]
            )

            if let self = self {
                self.isScanningObserver = KVOStateObserver(receiver: self, entity: central, property: \.isScanning)
            }

            self?.logger.debug("Initialized CBCentralManager.")
            return central
        } onCleanup: { [weak self] in
            self?.logger.debug("Destroyed CBCentralManager.")
            self?.isScanningObserver = nil
        }
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
    public func scanNearbyDevices(autoConnect: Bool = false) async {
        await withCheckedContinuation { continuation in
            dispatchQueue.async {
                self._scanNearbyDevices(autoConnect: autoConnect)
                continuation.resume()
            }
        }
    }

    /// If scanning, toggle the auto-connect feature.
    /// - Parameter autoConnect: Flag to turn on or off auto-connect
    public func setAutoConnect(_ autoConnect: Bool) async {
        await withCheckedContinuation { continuation in
            dispatchQueue.async {
                if self.shouldBeScanning {
                    self.autoConnect = autoConnect
                }
                continuation.resume()
            }
        }
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() async {
        await withCheckedContinuation { continuation in
            dispatchQueue.async {
                self._stopScanning()
                continuation.resume()
            }
        }
    }

    private func _scanNearbyDevices(autoConnect: Bool) {
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

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

    /// Reactive scan upon powered on.
    private func handlePoweredOn() {
        if shouldBeScanning && !isScanning {
            _scanNearbyDevices(autoConnect: autoConnect)
        }
    }

    private func _stopScanning(deinit isDeinit: Bool = false) {
        assert(isDeinit || isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

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

    private func handleStoppedScanning() {
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

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
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

        discoveredPeripherals.removeValue(forKey: id)

        if lastManuallyDisconnectedDevice == id {
            lastManuallyDisconnectedDevice = nil
        }

        checkForCentralDeinit()
    }

    /// De-initializes the Bluetooth Central if we currently don't use it.
    private func checkForCentralDeinit() {
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

        if !shouldBeScanning && discoveredPeripherals.isEmpty {
            _centralManager.destroy()
            self.state = .unknown
            self.lastManuallyDisconnectedDevice = nil
        }
    }

    func connect(peripheral: BluetoothPeripheral) async {
        logger.debug("Trying to connect to \(peripheral.cbPeripheral.debugIdentifier) ...")
        
        await withCheckedContinuation { continuation in
            dispatchQueue.async { [weak self] in
                guard let self = self else {
                    return
                }

                let cancelled = self.cancelStaleTask(for: peripheral)

                self.centralManager.connect(peripheral.cbPeripheral, options: nil)

                if cancelled {
                    self.scheduleStaleTaskForOldestActivityDevice(ignore: peripheral)
                }

                continuation.resume()
            }
        }
    }

    func disconnect(peripheral: BluetoothPeripheral) {
        logger.debug("Disconnecting peripheral \(peripheral.cbPeripheral.debugIdentifier) ...")
        // stale timer is handled in the delegate method
        centralManager.cancelPeripheralConnection(peripheral.cbPeripheral)

        dispatchQueue.async {
            self.lastManuallyDisconnectedDevice = peripheral.id
        }
    }

    func findDeviceDescription(for advertisementData: AdvertisementData) -> DeviceDescription? {
        configuredDevices.find(for: advertisementData, logger: logger)
    }

    // MARK: - Auto Connect

    private func kickOffAutoConnect() {
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

        guard autoConnect else {
            return // auto connect is disabled
        }

        guard autoConnectItem == nil && autoConnectDeviceCandidate != nil else {
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }

            self.autoConnectItem = nil

            guard let candidate = self.autoConnectDeviceCandidate else {
                return
            }

            Task {
                await candidate.connect()
            }
        }

        autoConnectItem = item
        dispatchQueue.asyncAfter(deadline: .now() + .seconds(Defaults.defaultAutoConnectDebounce), execute: item)
    }

    // MARK: - Stale Advertisement Timeout

    /// Schedule a new `DiscoveryStaleTimer`, cancelling any previous one.
    /// - Parameters:
    ///   - device: The device for which the timer is scheduled for.
    ///   - timeout: The timeout for which the timer is scheduled for.
    private func scheduleStaleTask(for device: BluetoothPeripheral, withTimeout timeout: TimeInterval) {
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

        let timer = DiscoveryStaleTimer(device: device.id) { [weak self] in
            self?.handleStaleTask()
        }

        self.staleTimer = timer
        timer.schedule(for: timeout, in: dispatchQueue)
    }

    private func scheduleStaleTaskForOldestActivityDevice(ignore device: BluetoothPeripheral? = nil) {
        if let oldestActivityDevice = oldestActivityDevice(ignore: device) {
            let intervalSinceLastActivity = Date.now.timeIntervalSince(oldestActivityDevice.lastActivity)
            let nextTimeout = max(0, advertisementStaleInterval - intervalSinceLastActivity)

            scheduleStaleTask(for: oldestActivityDevice, withTimeout: nextTimeout)
        }
    }

    private func cancelStaleTask(for device: BluetoothPeripheral) -> Bool {
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

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
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

        // when we are just interested in the min device, this operation is a bit cheaper then sorting the whole list
        return nearbyPeripheralsView
            // it's important to access the underlying state here
            .filter { $0.cbPeripheral.state == .disconnected && $0.id != device?.id }
            .min { lhs, rhs in
                lhs.lastActivity < rhs.lastActivity
            }
    }

    private func handleStaleTask() {
        assert(isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")
        staleTimer = nil // reset the timer

        let staleDevices = nearbyPeripheralsView.filter { device in
            device.isConsideredStale(interval: advertisementStaleInterval)
        }

        for device in staleDevices {
            logger.debug("Removing stale peripheral \(device.cbPeripheral.debugIdentifier)")
            // we know it won't be connected, therefore we just need to remove it
            clearDiscoveredPeripheral(forKey: device.id)
        }


        // schedule the next timeout for devices in the list
        scheduleStaleTaskForOldestActivityDevice()
    }

    
    deinit {
        _stopScanning(deinit: true)
        staleTimer?.cancel()
        autoConnectItem?.cancel()

        self.state = .poweredOff

        discoveredPeripherals = [:]
        self.centralDelegate = nil

        logger.debug("BluetoothManager destroyed")
    }
}


extension BluetoothManager: KVOReceiver {
    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) async {
        switch keyPath {
        case \CBCentralManager.isScanning:
            dispatchQueue.async {
                self.isScanning = value as! Bool // swiftlint:disable:this force_cast
                if !self.isScanning {
                    self.handleStoppedScanning()
                }
            }
        default:
            break
        }
    }
}


extension BluetoothManager: BluetoothScanner {
    @_documentation(visibility: internal)
    public var hasConnectedDevices: Bool {
        discoveredPeripherals.values.contains { peripheral in
            peripheral.state != .disconnected
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


        init(_ manager: BluetoothManager) {
            self.manager = manager
            super.init()
        }


        func centralManagerDidUpdateState(_ central: CBCentralManager) { // swiftlint:disable:this cyclomatic_complexity
            guard let manager else {
                return
            }

            switch central.state {
            case .poweredOn:
                // Start working with the peripheral
                logger.info("CBManager is powered on")
                manager.state = .poweredOn
                manager.handlePoweredOn()
            case .poweredOff:
                logger.info("CBManager is not powered on")
                manager.state = .poweredOff
            case .resetting:
                logger.info("CBManager is resetting")
                manager.state = .poweredOff
            case .unauthorized:
                switch CBManager.authorization {
                case .denied:
                    logger.log("You are not authorized to use Bluetooth")
                case .restricted:
                    logger.log("Bluetooth is restricted")
                default:
                    logger.log("Unexpected authorization")
                }
                manager.state = .unauthorized
            case .unknown:
                logger.log("CBManager state is unknown")
                manager.state = .unknown
            case .unsupported:
                logger.log("Bluetooth is not supported on this device")
                manager.state = .unsupported
            @unknown default:
                logger.log("A previously unknown central manager state occurred")
                manager.state = .unsupported
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
            guard let manager, manager.isScanning else {
                return
            }

            // rssi of 127 is a magic value signifying unavailability of the value.
            guard rssi.intValue >= manager.minimumRSSI, rssi.intValue != 127 else { // ensure the signal strength is not too low
                return // logging this would just be to verbose, so we don't.
            }

            let data = AdvertisementData(advertisementData: advertisementData)


            // check if we already seen this device!
            if let device = manager.discoveredPeripherals[peripheral.identifier] {
                device.markLastActivity()
                Task {
                    await device.update(advertisement: data, rssi: rssi.intValue)
                }

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
                schedulerKey: manager.isRunningBluetoothQueueKey,
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

        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            guard let manager else {
                return
            }

            guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
                logger.error("Received didConnect for unknown peripheral \(peripheral.debugIdentifier). Cancelling connection ...")
                manager.centralManager.cancelPeripheralConnection(peripheral)
                return
            }

            logger.debug("Peripheral \(peripheral.debugIdentifier) connected.")
            Task {
                await device.handleConnect()
            }
        }

        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            // Documentation reads: "Because connection attempts don’t time out, a failed connection usually indicates a transient issue,
            // in which case you may attempt connecting to the peripheral again."

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

            discardDevice(device: device)
        }


        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
                logger.error("Received didDisconnect for unknown peripheral \(peripheral.debugIdentifier).")
                return
            }

            if let error {
                logger.debug("Peripheral \(peripheral.debugIdentifier) disconnected due to an error: \(error)")
            } else {
                logger.debug("Peripheral \(peripheral.debugIdentifier) disconnected.")
            }

            discardDevice(device: device)
        }


        private func discardDevice(device: BluetoothPeripheral) {
            guard let manager else {
                return
            }

            assert(manager.isRunningWithinQueue, "\(#function) was run outside the bluetooth queue. This introduces data races.")

            if !manager.isScanning {
                device.markLastActivity()
                Task {
                    await device.handleDisconnect()
                }
                manager.clearDiscoveredPeripheral(forKey: device.id)
            } else {
                // we will keep discarded devices for 500ms before the stale timer kicks off
                let interval = max(0, manager.advertisementStaleInterval - 0.5)
                device.markLastActivity(.now - interval)
                Task {
                    await device.handleDisconnect()
                }

                // We just schedule the new timer if there is a device to schedule one for.
                manager.scheduleStaleTaskForOldestActivityDevice()
            }
        }
    }
} // swiftlint:disable:this file_length
