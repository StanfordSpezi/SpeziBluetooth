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
import OSLog
import OrderedCollections



/// Manages the Bluetooth connections, state, and data transfer.
@Observable
public class BluetoothManager: NSObject, CBCentralManagerDelegate {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    // TODO: whats the reason for this queue here?
    private let messageHandlerQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated, attributes: .concurrent)

    private let discoveryCriteria: Set<DiscoveryCriteria>
    private let minimumRSSI: Int // TODO: configurable

    /// Represents the current state of Bluetooth connection.
    private(set) var state: BluetoothState // TODO: decouple from central state!
    /// The list of discovered and connected bluetooth devices indexed by their identifier UUID.
    private var discoveredDevices: OrderedDictionary<UUID, BluetoothPeripheral> = [:]

    @ObservationIgnored private var centralManager: CBCentralManager! // swiftlint:disable:this implicitly_unwrapped_optional


    public var nearbyDevices: [BluetoothPeripheral] {
        Array(discoveredDevices.values)
    }

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
    init(discoverBy discoveryCriteria: Set<DiscoveryCriteria>, minimumRSSI: Int = -65) {
        self.discoveryCriteria = discoveryCriteria
        self.minimumRSSI = minimumRSSI
        self.state = .poweredOff // TODO: really? why do we map these states?
        
        super.init()

        // TODO one cannot manage when this is displayed!
        // TODO: custom queue for that?

        // TODO: we might just not show the alert, only when we query and are authorized?
        // TODO: instantiate later?
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    public func scanNearbyDevices() {
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
        // This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.

        guard rssi.intValue >= minimumRSSI else { // ensure the signal strength is not too low
            logger.debug("Discovered peripheral not in expected range, at \(rssi.intValue)")
            return
        }


        // TODO:

        // check if we already seen this device!
        if let device = discoveredDevices[peripheral.identifier] {
            // TODO: reset stale timer!
            return
        }

        logger.debug("Discovered \(peripheral.name ?? "unknown device") at \(rssi.intValue)")

        let device = BluetoothPeripheral(peripheral: peripheral, rssi: rssi)
        discoveredDevices[peripheral.identifier] = device // save local-copy, such CB doesn't deallocate it

        // TODO: how to notify clients?
        // TODO: support auto-connect (more options?)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let device = discoveredDevices[peripheral.identifier] {
            logger.error("Failed to connect to \(peripheral): \(String(describing: error))")
            device.cleanup()
        } else {
            // TODO: logger messsag
        }

        // finally clean up device connection?
        centralManager.cancelPeripheralConnection(peripheral) // TODO: review what this code actually does?
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = discoveredDevices[peripheral.identifier] else {
            // TODO: error log message
            return
        }

        logger.debug("Peripheral Connected") // TODO: log message
        device.handleConnect()
    }


    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // TODO: notify device class about disconnect?
        guard let device = self.discoveredDevices.removeValue(forKey: peripheral.identifier) else {
            // TODO: log
            return
        }

        logger.debug("Peripheral Disconnected") // TODO: detailed log message
        device.handleDisconnect()
    }

    
    deinit {
        stopScanning()
        self.state = .poweredOff
    }
}
