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
public class BluetoothManager: KVOReceiver {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    /// The dispatch queue for all Bluetooth related functionality. This is serial (not `.concurrent`) to ensure synchronization.
    private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)

    /// The discovery configuration describing how nearby devices are discovered.
    let discovery: Set<DiscoveryConfiguration>
    private let minimumRSSI: Int

    @ObservationIgnored private var centralManager: CBCentralManager! // swiftlint:disable:this implicitly_unwrapped_optional
    @ObservationIgnored private var delegate: Delegate? // swiftlint:disable:this weak_delegate
    @ObservationIgnored private var isScanningObserver: KVOStateObserver<BluetoothManager>?

    /// Represents the current state of the Bluetooth Manager.
    public private(set) var state: BluetoothState
    /// Whether or not we are currently scanning for nearby devices.
    public private(set) var isScanning: Bool
    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    /// The state is isolated to our `dispatchQueue`.
    private var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> = [:]

    /// The time interval after which an advertisement is considered stale and the device is removed.
    private let advertisementStaleInterval: TimeInterval // TODO: enforce minimum time? e.g. 1s? and maximum, 30s?
    @ObservationIgnored private var staleTimer: DiscoveryStaleTimer?

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
        let discoveryIds = discovery.compactMap { configuration in
            if case let .primaryService(uuid) = configuration.criteria {
                return uuid
            }
            return nil
        }

        return discoveryIds.isEmpty ? nil : discoveryIds
    }

    
    /// Initializes the BluetoothManager with provided services and optional message handlers.
    ///
    /// // TODO: code example?
    ///
    /// - Parameters:
    ///   - services: List of Bluetooth services to manage.
    ///   - messageHandlers: List of handlers for processing incoming Bluetooth messages.
    ///   - minimumRSSI: Minimum RSSI value to consider when discovering peripherals.
    public init(discovery: Set<DiscoveryConfiguration>, minimumRSSI: Int = -65, advertisementStaleTimeout: TimeInterval = 10) {
        // TODO: update docs!
        self.discovery = discovery
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = advertisementStaleTimeout

        switch CBCentralManager.authorization {
        case .denied, .restricted:
            self.state = .unauthorized
        default:
            self.state = .poweredOff
        }
        self.isScanning = false

        self.delegate = Delegate(self)

        // TODO: just lazy init this thing? how to delay (or repeatedly) show power alert?
        centralManager = CBCentralManager(delegate: self.delegate, queue: dispatchQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true])

        isScanningObserver = KVOStateObserver<BluetoothManager>(receiver: self, entity: centralManager, property: \.isScanning)
    }

    public func scanNearbyDevices() {
        // TODO: just scan for nearby devices? or also call retrieveConnectedPeripherals?
        //   let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: services.map(\.serviceUUID))
        //   logger.debug("Found connected Peripherals with transfer service: \(connectedPeripherals.debugDescription)")
        //   => might need to call connect on this?

        centralManager.scanForPeripherals(
            withServices: serviceDiscoveryIds,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    public func stopScanning() {
        if centralManager.isScanning { // transitively checks for state == .poweredOn
            centralManager.stopScan()
            logger.log("Scanning stopped")
        }
    }

    func handleStoppedScanning() {
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
            self.isScanning = value as! Bool // swiftlint:disable:this force_cast
            if !isScanning {
                handleStoppedScanning()
            }
        default:
            break
        }
    }

    func discoveryConfiguration(for advertisementData: AdvertisementData) -> DiscoveryConfiguration? {
        let configurations = discovery.filter { configuration in
            if case let .primaryService(uuid) = configuration.criteria,
               let advertisedServices = advertisementData.serviceUUIDs {
                return advertisedServices.contains(uuid)
            }
            // TODO: we could easily support name as well (if we support the performance degradation impact!)
            return false
        }

        if configurations.count > 1 {
            let criteria = configurations
                .map { $0.criteria.description }
                .joined(separator: ", ")
            logger.warning("Found ambiguous discovery configuration for peripheral. Peripheral matched all these criteria: \(criteria)")
        }

        return configurations.first
    }

    // MARK: - Stale Advertisement Timeout

    /// Schedule a new `DiscoveryStaleTimer`, cancelling any previous one.
    /// - Parameters:
    ///   - device: The device for which the timer is scheduled for.
    ///   - timeout: The timeout for which the timer is scheduled for.
    private func scheduleStaleTask(for device: BluetoothPeripheral, withTimeout timeout: TimeInterval) {
        let timer = DiscoveryStaleTimer(device: device.id) { [weak self] in
            self?.handleStaleTask()
        }

        self.staleTimer = timer
        timer.schedule(for: timeout, in: dispatchQueue)
    }

    private func scheduleStaleTaskForOldestActivityDevice(ignore device: BluetoothPeripheral? = nil) {
        if let oldestActivityDevice = oldestActivityDevice(ignore: device) {
            let nextTimeout = Date.now.timeIntervalSince(oldestActivityDevice.lastActivity)
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
            // we know it won't be connected, therefore we just need to remove it
            discoveredPeripherals.removeValue(forKey: device.id)
            // TODO: any races?
        }


        // schedule the next timeout for devices in the list
        scheduleStaleTaskForOldestActivityDevice()
    }

    
    deinit {
        stopScanning()
        staleTimer?.cancel()
        self.state = .poweredOff
        discoveredPeripherals = [:] // TODO: disconnect devices?

        logger.debug("BluetoothManager destroyed")
    }
}


// MARK: Delegate
extension BluetoothManager {
    private class Delegate: NSObject, CBCentralManagerDelegate {
        private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManagerDelegate")

        private unowned var manager: BluetoothManager


        init(_ manager: BluetoothManager) {
            self.manager = manager
            super.init()
        }


        func centralManagerDidUpdateState(_ central: CBCentralManager) {
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
            // rssi of 127 is a magic value signifying unavailability of the value.
            // TODO: not true?: Connecting to such a device will most likely crash.
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
                return
            }

            // TODO: see how advertisement data looks like for peripherals that advertise a primary service
            //  + are .services pre-populated there?
            //   : Refer to `isPrimary` property for fallback!

            logger.debug("Discovered peripheral \(peripheral.debugIdentifier) at \(rssi.intValue) dB (data: \(advertisementData))")

            let device = BluetoothPeripheral(manager: manager, peripheral: peripheral, advertisementData: data, rssi: rssi.intValue)
            manager.discoveredPeripherals[peripheral.identifier] = device // save local-copy, such CB doesn't deallocate it


            if manager.staleTimer == nil {
                // There is no stale timer running. So new device will be the one with the oldest activity. Schedule ...
                manager.scheduleStaleTask(for: device, withTimeout: manager.advertisementStaleInterval)
            }

            // TODO: support auto-connect (more options?)
        }

        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            // Documentation reads: "Because connection attempts don’t time out, a failed connection usually indicates a transient issue,
            // in which case you may attempt connecting to the peripheral again."

            guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
                logger.warning("Unknown peripheral \(peripheral.debugIdentifier) failed with error: \(String(describing: error))")
                manager.centralManager.cancelPeripheralConnection(peripheral)
                return
            }

            logger.error("Failed to connect to \(peripheral): \(String(describing: error))")
            Task {
                await device.disconnect() // TODO: attempt reconnect, instead? OR make it configurable?
            }
        }

        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
                logger.error("Received didConnect for unknown peripheral \(peripheral.debugIdentifier). Cancelling connection ...")
                manager.centralManager.cancelPeripheralConnection(peripheral)
                return
            }

            logger.debug("Peripheral \(peripheral.debugIdentifier) connected ...")
            Task {
                await device.handleConnect()
            }
        }


        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard let device = manager.discoveredPeripherals[peripheral.identifier] else {
                logger.error("Received didDisconnect for unknown peripheral \(peripheral.debugIdentifier).")
                return
            }

            logger.debug("Peripheral \(peripheral.debugIdentifier) disconnected ...")

            // we will keep disconnected devices for 25% of the stale interval time.
            let interval = manager.advertisementStaleInterval * 0.25 // TODO: only if isScanning is true?
            device.handleDisconnect(disconnectActivityInterval: interval)

            // We just schedule the new timer if there is a device to schedule one for.
            manager.scheduleStaleTaskForOldestActivityDevice()
        }
    }
}
