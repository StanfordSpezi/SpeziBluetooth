//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import Combine
import CoreBluetooth
import NIO
import OSLog


class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    // We use an implicity unwrapped optional here as we can gurantee that the value will be available after the initialization of the
    // `BluetoothManager` and we refer to the `self` in the initializer of the `CBCentralManager`.
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var centralManager: CBCentralManager!
    private var discoveredPeripheral: CBPeripheral?
    private var transferCharacteristics: [CBCharacteristic] = []
    private let minimumRSSI: Int
    
    private var messageHandlers: [BluetoothMessageHandler]
    private let services: [BluetoothService]
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "BluetoothManager")
    private let messageHandlerQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated, attributes: .concurrent)
    
    @Published private(set) var state: BluetoothModuleState
    
    
    private var serviceIDs: [CBUUID] {
        services.map(\.serviceUUID)
    }
    
    private var characteristicUUIDs: [CBUUID] {
        services.flatMap(\.characteristicUUIDs)
    }
    
    
    /// <#Description#>
    /// - Parameters:
    ///   - services: <#services description#>
    ///   - messageHandlers: <#messageHandlers description#>
    ///   - minimumRSSI: <#minimumRSSI description#>
    init(services: [BluetoothService], messageHandlers: [BluetoothMessageHandler] = [], minimumRSSI: Int = -65) {
        self.minimumRSSI = minimumRSSI
        self.services = services
        self.messageHandlers = messageHandlers
        self.state = .poweredOff
        
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    
    /// Write a `ByteBuffer` to the connected peripheral.
    /// - Parameter data: <#data description#>
    /// - Parameter service: <#service description#>
    /// - Parameter characteristic: <#characteristic description#>
    func write(data: Data, service: CBUUID, characteristic: CBUUID) throws {
        guard let discoveredPeripheral = discoveredPeripheral,
              let transferCharacteristic = transferCharacteristics.first(where: { $0.uuid == characteristic }),
              transferCharacteristic.service?.uuid == service else {
            throw BluetoothError.notConnected
        }
        
        let hexDescription = data.reduce(into: "") {
            $0.append(String(format: "%02x", $1))
        }
        logger.debug("Write \(data.count) bytes: \(hexDescription)")
        
        discoveredPeripheral.writeValue(data, for: transferCharacteristic, type: .withResponse)
    }
    
    /// <#Description#>
    /// - Parameter messageHandler: <#messageHandler description#>
    func add(messageHandler: BluetoothMessageHandler) {
        messageHandlers.append(messageHandler)
    }
    
    /// <#Description#>
    /// - Parameter messageHandler: <#messageHandler description#>
    func remove(messageHandler: BluetoothMessageHandler) {
        messageHandlers.removeAll(where: { $0 === messageHandler })
    }
    

    // MARK: - Helper Methods
    
    /// We will first check if we are already connected to our counterpart
    /// Otherwise, scan for peripherals - specifically for our service's 128bit CBUUID
    private func retrievePeripheral() {
        self.state = .scanning
        
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: services.map(\.serviceUUID))
        
        logger.debug("Found connected Peripherals with transfer service: \(connectedPeripherals.debugDescription)")
        
        if let connectedPeripheral = connectedPeripherals.last {
            logger.debug("Connecting to peripheral \(connectedPeripheral)")
            self.discoveredPeripheral = connectedPeripheral
            centralManager.connect(connectedPeripheral, options: nil)
        } else {
            // We were not connected to our counterpart, so start scanning
            centralManager.scanForPeripherals(
                withServices: serviceIDs,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }
    
    
    /// Call this when things either go wrong, or you're done with the connection.
    /// This cancels any subscriptions if there are any, or straight disconnects if not.
    /// (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
    private func cleanup() {
        self.state = .disconnected
        
        // Don't do anything if we're not connected
        guard let discoveredPeripheral = discoveredPeripheral,
              case .connected = discoveredPeripheral.state else {
            return
        }
        
        for service in discoveredPeripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristicUUIDs.contains(characteristic.uuid) && characteristic.isNotifying {
                    // It is notifying, so unsubscribe
                    self.discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                }
            }
        }
        
        // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager.cancelPeripheralConnection(discoveredPeripheral)
    }
    
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Start working with the peripheral
            logger.info("CBManager is powered on")
            retrievePeripheral()
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
            self.state = .poweredOff
        case .unsupported:
            logger.log("Bluetooth is not supported on this device")
            self.state = .poweredOff
        @unknown default:
            logger.log("A previously unknown central manager state occurred")
            self.state = .poweredOff
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        // We have to use NSNumber to confrom to the `CBCentralManagerDelegate` delegate methods.
        // swiftlint:disable:next legacy_objc_type
        rssi: NSNumber
    ) {
        // This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
        // We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
        // we start the connection process
                                                                                                    
        // Reject if the signal strength is too low to attempt data transfer.
        // Change the minimum RSSI value depending on your app’s use case.
        guard rssi.intValue >= minimumRSSI else {
            logger.info("Discovered perhiperal not in expected range, at \(rssi.intValue)")
            return
        }
        
        logger.info("Discovered \(peripheral.name ?? "unknown device") at \(rssi.intValue)")
        
        // Device is in range - have we already seen it?
        if discoveredPeripheral != peripheral {
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
            discoveredPeripheral = peripheral
            
            // And finally, connect to the peripheral.
            logger.info("Connecting to perhiperal \(peripheral)")
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // If the connection fails for whatever reason, we need to deal with it.
        logger.error("Failed to connect to \(peripheral): \(String(describing: error))")
        cleanup()
        self.state = .disconnected
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
        logger.log("Peripheral Connected")
        self.state = .connected
        
        // Stop scanning
        centralManager.stopScan()
        logger.log("Scanning stopped")
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices(serviceIDs)
    }
    

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Once the disconnection happens, we need to clean up our local copy of the peripheral
        logger.log("Perhiperal Disconnected")
        discoveredPeripheral = nil
        transferCharacteristics = []
        self.state = .disconnected
        
        retrievePeripheral()
    }
    
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // The peripheral letting us know when services have been invalidated.
        for service in invalidatedServices where serviceIDs.contains(service.uuid) {
            logger.log("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices(serviceIDs)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // The Transfer Service was discovered
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            cleanup()
            return
        }
        
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else {
            return
        }
        
        for service in peripheralServices {
            if let characteristicIDs = services.first(where: { $0.serviceUUID == service.uuid })?.characteristicUUIDs {
                peripheral.discoverCharacteristics(characteristicIDs, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // The Transfer characteristic was discovered.
        // Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
        
        // Deal with errors (if any).
        if let error = error {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }
        
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics,
              let serviceConfiguration = services.first(where: { $0.serviceUUID == service.uuid }) else {
            return
        }
        
        for characteristic in serviceCharacteristics where serviceConfiguration.characteristicUUIDs.contains(characteristic.uuid) {
            // If it is, subscribe to it
            transferCharacteristics.append(characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // This callback lets us know more data has arrived via notification on the characteristic
        
        // Deal with errors (if any)
        if let error = error {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }
        
        guard let serviceId = characteristic.service?.uuid ?? serviceId(forCharacteristic: characteristic.uuid) else {
            logger.error("Error identifying service id for characteristic \(characteristic.uuid)")
            return
        }
        
        guard let data = characteristic.value else {
            return
        }
                
        for messageHandler in messageHandlers {
            messageHandlerQueue.async {
                Task {
                    await messageHandler.recieve(data, service: serviceId, characteristic: characteristic.uuid)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // he peripheral letting us know whether our subscribe/unsubscribe happened or not
        
        // Deal with errors (if any)
        if let error = error {
            logger.error("Error changing notification state: \(error.localizedDescription)")
            return
        }
        
        // Exit if it's not the transfer characteristic
        guard characteristicUUIDs.contains(characteristic.uuid) else {
            return
        }
        
        if characteristic.isNotifying {
            // Notification has started
            logger.log("Notification began on \(characteristic.uuid.uuidString)")
        } else {
            // Notification has stopped, so disconnect from the peripheral
            logger.log("Notification stopped on \(characteristic.uuid.uuidString). Disconnecting")
            cleanup()
        }
    }
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        // This is called when peripheral is ready to accept more data when using write without response
        logger.log("Peripheral is ready")
        self.state = .connected
    }
    
    
    private func serviceId(forCharacteristic characteristic: CBUUID) -> CBUUID? {
        services.first(where: { $0.characteristicUUIDs.contains(characteristic) })?.serviceUUID
    }
    
    
    deinit {
        centralManager.stopScan()
        self.state = .poweredOff
        logger.log("Scanning stopped")
    }
}
