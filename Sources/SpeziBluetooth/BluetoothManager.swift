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
public class BluetoothManager: NSObject, CBCentralManagerDelegate { // TODO: make delegate separate?
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    // TODO: whats the reason for this queue here?
    private let messageHandlerQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated, attributes: .concurrent)
    @ObservationIgnored private var centralManager: CBCentralManager! // swiftlint:disable:this implicitly_unwrapped_optional

    private let discoveryCriteria: Set<DiscoveryCriteria> // TODO: how to search for a name?
    private let minimumRSSI: Int // TODO: configurable
    /// The time interval after which an advertisement is considered stale and the device is removed.
    private let advertisementStaleTimeout: TimeInterval // TODO: enforce minimum time? e.g. 1s?

    /// Represents the current state of Bluetooth connection.
    private(set) var state: BluetoothState // TODO: decouple from central state!
    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    private var discoveredDevices: OrderedDictionary<UUID, BluetoothPeripheral> = [:] // TODO: those are never removed! what to do after disconnect?

    @ObservationIgnored private var devicesStaleTimer: Task<Void, Never>? {
        // TODO: capture the scheduling time and/or the device for which we scheduled? so we can calculate the diff?
        willSet {
            devicesStaleTimer?.cancel()
        }
    }

    // TODO: docs
    public var nearbyDevices: [BluetoothPeripheral] {
        Array(discoveredDevices.values)
    }

    // TODO: docs
    public var nearbyDevicesView: OrderedDictionary<UUID, BluetoothPeripheral>.Values {
        discoveredDevices.values
    }

    private var serviceDiscoveryIds: [CBUUID] {
        discoveryCriteria.compactMap { criteria in
            if case let .primaryService(uuid) = criteria {
                return uuid
            }
            return nil
        }
    }

    
    /// Initializes the BluetoothManager with provided services and optional message handlers.
    ///
    /// - Parameters:
    ///   - services: List of Bluetooth services to manage.
    ///   - messageHandlers: List of handlers for processing incoming Bluetooth messages.
    ///   - minimumRSSI: Minimum RSSI value to consider when discovering peripherals.
    init(discoverBy discoveryCriteria: Set<DiscoveryCriteria>, minimumRSSI: Int = -65, advertisementStaleTimeout: TimeInterval = 10) { // TODO: update docs!
        self.discoveryCriteria = discoveryCriteria
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleTimeout = advertisementStaleTimeout
        self.state = .poweredOff // TODO: might be unauthorized as well?

        super.init()

        // TODO: use custom queue for central manager?
        // TODO: instantiate central manager later for authorization pop up?

        // we show the power alert upon scanning
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    public func scanNearbyDevices() {
        // TODO: make a simple modifier that registers all onAppear, onDisappear, onForeground, onBackground handlers!
        // TODO: autoconnect modifier => find first and then connect if unique (for a certain back off period)?

        // TODO: just scan for nearby devices? or also call retrieveConnectedPeripherals?
        //   let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: services.map(\.serviceUUID))
        //   logger.debug("Found connected Peripherals with transfer service: \(connectedPeripherals.debugDescription)")
        //   => might need to call connect on this?

        centralManager.scanForPeripherals(
            withServices: serviceDiscoveryIds,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true,
                CBCentralManagerOptionShowPowerAlertKey: true // TODO: does this work?
            ]
        )
    }

    public func stopScanning() {
        centralManager.stopScan()
        logger.log("Scanning stopped")
    }
    
    
    // MARK: - CBCentralManagerDelegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // TODO: move into extension!
        switch central.state {
        case .poweredOn:
            // Start working with the peripheral
            logger.info("CBManager is powered on")
            self.state = .poweredOn

            // TODO: configure auto discovery?
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

    // TODO: 10s a good advertising max?
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        // We have to use NSNumber to conform to the `CBCentralManagerDelegate` delegate methods.
        // swiftlint:disable:next legacy_objc_type
        rssi: NSNumber
    ) {
        guard rssi.intValue >= minimumRSSI else { // ensure the signal strength is not too low
            return // TODO: we don't log. Just to verbose. Anything else?
        }


        // check if we already seen this device!
        if let device = discoveredDevices[peripheral.identifier] {
            Task {
                await device.markActivity()
                // TODO: reschedule timer based on the smallest timeout? (only relevant if we scheduled the current one for the current device?)
            }
            return // TODO: is the identifier stable??
        }

        logger.debug("Discovered peripheral \(peripheral.logName) at \(rssi.intValue) dB")

        // TODO: are peripheral.services populated?

        let device = BluetoothPeripheral(central: centralManager, peripheral: peripheral, rssi: rssi)
        discoveredDevices[peripheral.identifier] = device // save local-copy, such CB doesn't deallocate it

        // if there isn't a stale task already, we now
        // TODO: support auto-connect (more options?)
    }

    private func scheduleStaleTask() {
        guard devicesStaleTimer == nil else {
            return // there is an earlier timeout!
        }

        self.devicesStaleTimer = Task { [weak self] in  // TODO: weak self!!!
            try? await Task.sleep(for: .seconds(self?.advertisementStaleTimeout ?? 0))
            // TODO: handle stale timer!

            // TODO: check if we need to reschedule next smallest one?

        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Documentation reads: "Because connection attempts don’t time out, a failed connection usually indicates a transient issue,
        // in which case you may attempt connecting to the peripheral again."
        // TODO: attempt reconnect?

        if let device = discoveredDevices[peripheral.identifier] {
            // TODO: is this logger message accurate?
            logger.error("Failed to connect to \(peripheral): \(String(describing: error))")
            Task {
                await device.cleanup()
                // TODO: we don't wait for this before we call cancel!
            }
        } else {
            logger.warning("Unknown peripheral \(peripheral.logName) failed with error: \(String(describing: error))")
        }

        // finally clean up device connection?
        centralManager.cancelPeripheralConnection(peripheral) // TODO: review what this code actually does?
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = discoveredDevices[peripheral.identifier] else {
            logger.error("Received didConnect for unknown peripheral \(peripheral.logName). Cancelling connection ...")
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        logger.debug("Peripheral \(peripheral.logName) connected ...")
        Task {
            await device.handleConnect()
        }
    }


    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let device = self.discoveredDevices.removeValue(forKey: peripheral.identifier) else {
            logger.error("Received didDisconnect for unknown peripheral \(peripheral.logName).")
            return
        }

        logger.debug("Peripheral \(peripheral.logName) disconnected ...")
        Task {
            await device.handleDisconnect()
        }
    }

    
    deinit {
        stopScanning()
        devicesStaleTimer?.cancel()
        self.state = .poweredOff
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
