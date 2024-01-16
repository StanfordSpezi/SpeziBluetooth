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
@Observable
public class BluetoothManager: NSObject, CBCentralManagerDelegate, KVOReceiver { // TODO: make delegate separate?
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    /// The dispatch queue for all Bluetooth related functionality. This is serial (not `.concurrent`) to ensure synchronization.
    private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)

    private let discovery: Set<DiscoveryConfiguration>
    private let minimumRSSI: Int

    @ObservationIgnored private var centralManager: CBCentralManager! // swiftlint:disable:this implicitly_unwrapped_optional
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

        super.init()

        // TODO: spezi module should allow later instantiation of the BluetoothManager(?), show power alert!

        // we show the power alert upon scanning
        centralManager = CBCentralManager(delegate: self, queue: dispatchQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true])

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
        logger.debug("Trying to connect to \(peripheral.cbPeripheral.logName) ...")
        
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
    
    // MARK: - CBCentralManagerDelegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // TODO: move into extension!
        switch central.state {
        case .poweredOn:
            // Start working with the peripheral
            logger.info("CBManager is powered on")
            self.state = .poweredOn
        case .poweredOff:
            logger.info("CBManager is not powered on")
            self.state = .poweredOff
        case .resetting:
            logger.info("CBManager is resetting")
            self.state = .poweredOff
        case .unauthorized:
            switch CBManager.authorization {
            case .denied:
                logger.log("You are not authorized to use Bluetooth")
            case .restricted:
                logger.log("Bluetooth is restricted")
            default:
                logger.log("Unexpected authorization")
            }
            self.state = .unauthorized
        case .unknown:
            logger.log("CBManager state is unknown")
            self.state = .unsupported
        case .unsupported:
            logger.log("Bluetooth is not supported on this device")
            self.state = .unsupported
        @unknown default:
            logger.log("A previously unknown central manager state occurred")
            self.state = .unsupported
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        // We have to use NSNumber to conform to the `CBCentralManagerDelegate` delegate methods.
        // swiftlint:disable:next legacy_objc_type
        rssi: NSNumber
    ) {
        // rssi of 127 is a magic value signifying unavailability of the value.
        // TODO: not true: Connecting to such a device will most likely crash.
        guard rssi.intValue >= minimumRSSI, rssi.intValue != 127 else { // ensure the signal strength is not too low
            return // logging this would just be to verbose, so we don't.
        }


        // check if we already seen this device!
        if let device = discoveredPeripherals[peripheral.identifier] {
            device.markActivity()

            if self.cancelStaleTask(for: device) {
                // current device was earliest to go stale, schedule timeout for next oldest device
                scheduleStaleTaskForOldestActivityDevice()
            }
            return
        }

        // TODO: see how advertisement data looks like for peripherals that advertise a primary service
        //  + are .services prepopulated there?
        // TODO: Refer to `isPrimary` property for fallback!

        // TODO: inspect CBAdvertisementDataIsConnectable?
        // TODO: make advertisement data accessible: https://github.com/Polidea/RxBluetoothKit/blob/master/Source/AdvertisementData.swift

        logger.debug("Discovered peripheral \(peripheral.logName) at \(rssi.intValue) dB (data: \(advertisementData))")

        // TODO: how to pass requestedCharacteristics!???
        let device = BluetoothPeripheral(manager: self, peripheral: peripheral, requestedCharacteristics: [:], rssi: rssi)
        discoveredPeripherals[peripheral.identifier] = device // save local-copy, such CB doesn't deallocate it


        if staleTimer == nil {
            // There is no stale timer running. So new device will be the one with the oldest activity. Schedule ...
            scheduleStaleTask(for: device, withTimeout: advertisementStaleInterval)
        }

        // TODO: support auto-connect (more options?)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Documentation reads: "Because connection attempts don’t time out, a failed connection usually indicates a transient issue,
        // in which case you may attempt connecting to the peripheral again."

        guard let device = discoveredPeripherals[peripheral.identifier] else {
            logger.warning("Unknown peripheral \(peripheral.logName) failed with error: \(String(describing: error))")
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        logger.error("Failed to connect to \(peripheral): \(String(describing: error))")
        Task {
            await device.disconnect() // TODO: attempt reconnect, instead? OR make it configurable?
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = discoveredPeripherals[peripheral.identifier] else {
            logger.error("Received didConnect for unknown peripheral \(peripheral.logName). Cancelling connection ...")
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        logger.debug("Peripheral \(peripheral.logName) connected ...")
        device.handleConnect()
    }


    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let device = discoveredPeripherals[peripheral.identifier] else {
            logger.error("Received didDisconnect for unknown peripheral \(peripheral.logName).")
            return
        }

        logger.debug("Peripheral \(peripheral.logName) disconnected ...")

        // we will keep disconnected devices for 25% of the stale interval time.
        let interval = advertisementStaleInterval * 0.25 // TODO: only if isScanning is true?
        device.handleDisconnect(disconnectActivityInterval: interval)

        // We just schedule the new timer if there is a device to schedule one for.
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


extension CBPeripheral {
    var logName: String { // TODO: rename and move!
        if let name {
            "'\(name)' @ \(identifier)"
        } else {
            "\(identifier)"
        }
    }
}
