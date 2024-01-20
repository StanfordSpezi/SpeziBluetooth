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


/// Manages the Bluetooth connections, state, and data transfer.
///
/// // TODO: docs and proper code example!
///
/// ## Topics
///
/// ### Create a Bluetooth Manager
///
/// - ``init(discovery:minimumRSSI:advertisementStaleTimeout:)``
///
/// ### Tracking State
///
/// - ``state``
/// - ``isScanning``
///
/// ### Discovering nearby Peripherals
/// - ``scanNearbyDevices()``
/// - ``stopScanning()``
/// - ``nearbyPeripherals``
/// - ``nearbyPeripheralsView``
@Observable
public class BluetoothManager: KVOReceiver, BluetoothScanner {
    public enum Defaults {
        /// The default timeout after which stale advertisements are removed.
        public static let defaultStaleTimeout: TimeInterval = 10
        /// The minimum rssi of a peripheral to consider it for discovery.
        public static let defaultMinimumRSSI = -65
        /// The default time in seconds after which we check for auto connectable devices after the initial advertisement.
        public static let defaultAutoConnectDebounce: Int = 2
    }

    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    /// The dispatch queue for all Bluetooth related functionality. This is serial (not `.concurrent`) to ensure synchronization.
    private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)

    /// The device descriptions describing how nearby devices are discovered.
    private let configuredDevices: Set<DeviceDescription>
    /// The minimum rssi that is required for a device to be discovered.
    private let minimumRSSI: Int
    /// The time interval after which an advertisement is considered stale and the device is removed.
    private let advertisementStaleInterval: TimeInterval

    @ObservationIgnored private var centralManager: CBCentralManager! // swiftlint:disable:this implicitly_unwrapped_optional
    @ObservationIgnored private var delegate: Delegate? // swiftlint:disable:this weak_delegate
    @ObservationIgnored private var isScanningObserver: KVOStateObserver<BluetoothManager>?

    /// Represents the current state of the Bluetooth Manager.
    public private(set) var state: BluetoothState
    /// Whether or not we are currently scanning for nearby devices.
    public private(set) var isScanning: Bool
    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    /// The state is isolated to our `dispatchQueue`.
    private(set) var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> = [:]

    @ObservationIgnored private var autoConnect = false
    @ObservationIgnored private var autoConnectItem: DispatchWorkItem?
    @ObservationIgnored private var staleTimer: DiscoveryStaleTimer?

    /// Checks and determines the device candidate for auto-connect.
    ///
    /// Checks if there is exactly one, disconnected peripheral that can be used for the auto-connect feature.
    private var autoConnectDeviceCandidate: BluetoothPeripheral? {
        guard discoveredPeripherals.count == 1,
              let firstDevice = discoveredPeripherals.values.first,
              firstDevice.state == .disconnected else {
            return nil
        }

        return firstDevice
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
            if case let .primaryService(uuid) = configuration.discoveryCriteria {
                return uuid
            }
            return nil
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
        self.configuredDevices = devices
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = max(1, advertisementStaleInterval)

        switch CBCentralManager.authorization {
        case .denied, .restricted:
            self.state = .unauthorized
        default:
            self.state = .poweredOff
        }
        self.isScanning = false

        self.delegate = Delegate(self)

        // TODO: just lazy init this thing? how to delay (or repeatedly) show power alert?
        //   => if we retrieve connected devices can we reconstruct the central manager and "reconnect"?
        //   => might just lazy init and deinit if the last device disconnects and isScanning is false?
        centralManager = CBCentralManager(delegate: self.delegate, queue: dispatchQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true])

        isScanningObserver = KVOStateObserver<BluetoothManager>(receiver: self, entity: centralManager, property: \.isScanning)
    }

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``DeviceDescription`` provided in the initializer.
    /// All discovered devices can be accessed through the ``nearbyPeripherals`` or ``nearbyPeripheralsView`` property.
    ///
    /// - Note: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(with:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameter autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    public func scanNearbyDevices(autoConnect: Bool = false) {
        guard !centralManager.isScanning else {
            return
        }

        // TODO: append connected: centralManager.retrieveConnectedPeripherals(withServices: services.map(\.serviceUUID))


        self.dispatchQueue.async {
            self.autoConnect = autoConnect
        }

        centralManager.scanForPeripherals(
            withServices: serviceDiscoveryIds,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() {
        if centralManager.isScanning { // transitively checks for state == .poweredOn
            centralManager.stopScan()
            logger.log("Scanning stopped")
        }
    }

    private func handleStoppedScanning() {
        self.autoConnect = false

        let devices = nearbyPeripheralsView.filter { device in
            device.state == .disconnected
        }

        for device in devices {
            discoveredPeripherals.removeValue(forKey: device.id)
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
    }

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

    func findDeviceDescription(for advertisementData: AdvertisementData) -> DeviceDescription? {
        configuredDevices.find(for: advertisementData, logger: logger)
    }

    // MARK: - Auto Connect

    private func kickOffAutoConnect() {
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

            // TODO: ensure that we don't re-connect to a manually disconnected device

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
        // TODO: consider scheduling a fixed timer!!
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
        nearbyPeripheralsView
            .filter { $0.state == .disconnected && $0.id != device?.id }
            .min { lhs, rhs in
                lhs.lastActivity < rhs.lastActivity
            }
    }

    private func handleStaleTask() {
        staleTimer = nil // reset the timer

        let staleDevices = nearbyPeripheralsView.filter { device in
            device.isConsideredStale(interval: advertisementStaleInterval)
        }

        for device in staleDevices {
            logger.debug("Removing stale peripheral \(device.cbPeripheral.debugIdentifier)")
            // we know it won't be connected, therefore we just need to remove it
            discoveredPeripherals.removeValue(forKey: device.id)
        }


        // schedule the next timeout for devices in the list
        scheduleStaleTaskForOldestActivityDevice()
    }

    
    deinit {
        stopScanning()
        staleTimer?.cancel()
        self.state = .poweredOff


        discoveredPeripherals = [:]
        self.centralManager.delegate = nil

        logger.debug("BluetoothManager destroyed")
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
                manager.state = .unsupported
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
                device.update(advertisement: data, rssi: rssi.intValue)

                if manager.cancelStaleTask(for: device) {
                    // current device was earliest to go stale, schedule timeout for next oldest device
                    manager.scheduleStaleTaskForOldestActivityDevice()
                }

                manager.kickOffAutoConnect()
                return
            }

            logger.debug("Discovered peripheral \(peripheral.debugIdentifier) at \(rssi.intValue) dB (data: \(advertisementData))")

            let device = BluetoothPeripheral(manager: manager, peripheral: peripheral, advertisementData: data, rssi: rssi.intValue)
            manager.discoveredPeripherals[peripheral.identifier] = device // save local-copy, such CB doesn't deallocate it


            if manager.staleTimer == nil {
                // There is no stale timer running. So new device will be the one with the oldest activity. Schedule ...
                manager.scheduleStaleTask(for: device, withTimeout: manager.advertisementStaleInterval)
            }

            manager.kickOffAutoConnect()
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

            logger.error("Failed to connect to \(peripheral): \(String(describing: error))")
            Task {
                await device.disconnect() // TODO: attempt reconnect, instead? OR make it configurable? reconnect tries?
            }
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


        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard let manager else {
                return
            }

            guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
                logger.error("Received didDisconnect for unknown peripheral \(peripheral.debugIdentifier).")
                return
            }

            logger.debug("Peripheral \(peripheral.debugIdentifier) disconnected.")

            if !manager.isScanning {
                device.handleDisconnect()
                manager.discoveredPeripherals.removeValue(forKey: device.id)
            } else {
                // we will keep disconnected devices for 500ms before the stale timer kicks off
                let interval = max(0, manager.advertisementStaleInterval - 0.5)
                device.handleDisconnect(disconnectActivityInterval: interval)

                // We just schedule the new timer if there is a device to schedule one for.
                manager.scheduleStaleTaskForOldestActivityDevice()
            }
        }
    }
}
