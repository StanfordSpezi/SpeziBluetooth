//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import BluetoothServices
import CoreBluetooth
import OSLog
import SpeziBluetooth

// TODO: how to we test remote disconnects? => characteristic stopping advertising for a few seconds?

class TestService {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "TestService")

    private weak var peripheral: TestPeripheral?
    let service: CBMutableService

    let eventLog: CBMutableCharacteristic
    // TODO: private let readCharacteristic: CBMutableCharacteristic
    // TODO: private let writeCharacteristic: CBMutableCharacteristic
    // TODO: private let readWriteCharacteristic: CBMutableCharacteristic

    init(peripheral: TestPeripheral) {
        self.peripheral = peripheral
        self.service = CBMutableService(type: .testService, primary: true)

        self.eventLog = CBMutableCharacteristic(type: .eventLogCharacteristic, properties: [.indicate], value: nil, permissions: [])

        service.characteristics = [eventLog]
    }


    @MainActor
    func logEvent(_ event: EventLog) async {
        guard let peripheral else {
            logger.error("Couldn't log event with missing peripheral!")
            return
        }

        await peripheral.updateValue(event, for: eventLog)
    }
}


@main
class TestPeripheral: NSObject, CBPeripheralManagerDelegate {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "TestPeripheral")
    private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth-peripheral", qos: .userInitiated)

    private var peripheralManager: CBPeripheralManager!

    private(set) var testService: TestService?
    private(set) var state: CBManagerState = .unknown

    @MainActor private var queuedUpdates: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: dispatchQueue)
    }

    static func main() {
        let peripheral = TestPeripheral()
        peripheral.logger.info("Initialized")
        while true {}
    }

    func startAdvertising() {
        guard let testService else {
            logger.error("Service was not available after starting advertising!")
            return
        }

        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [testService.service.uuid],
            CBAdvertisementDataLocalNameKey: "SpeziBluetooth TestPeripheral"
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        // TODO: https://stackoverflow.com/questions/51576340/corebluetooth-stopadvertising-does-not-stop
        // => remove all services?
    }

    @MainActor
    func updateValue<Value: ByteEncodable>(_ value: Value, for characteristic: CBMutableCharacteristic, for centrals: [CBCentral]? = nil) async {
        while !queuedUpdates.isEmpty {
            await withCheckedContinuation { continuation in
                queuedUpdates.append(continuation)
            }
        }

        let data = value.encode()

        await withCheckedContinuation { continuation in
            queuedUpdates.append(continuation)
            peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: centrals)
        }
    }

    @MainActor
    private func receiveManagerIsReady() {
        guard let first = queuedUpdates.first else {
            return
        }
        queuedUpdates.removeFirst()
        first.resume()

        guard let queued = queuedUpdates.first else {
            return
        }
        queuedUpdates.removeFirst()
        queued.resume()
    }

    private func addServices() {
        peripheralManager.removeAllServices() // TODO: required?

        let service = TestService(peripheral: self)
        self.testService = service

        peripheralManager.add(service.service)
    }

    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger.debug("PeripheralManager state is now \("\(peripheral.state)")")
        state = peripheral.state

        if case .poweredOn = state {
            addServices()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            logger.error("Error adding service \(service.uuid): \(error.localizedDescription)")
            return
        }

        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            logger.error("Error starting advertising: \(error.localizedDescription)")
        } else {
            logger.info("Peripheral advertising started successfully!")
        }
    }

    // MARK: - Interactions

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard let testService else {
            logger.error("Service was not available within \(#function)")
            return
        }

        Task { @MainActor in
            await testService.logEvent(.subscribedToNotification(characteristic.uuid))
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard let testService else {
            logger.error("Service was not available within \(#function)")
            return
        }

        Task { @MainActor in
            await testService.logEvent(.unsubscribedToNotification(characteristic.uuid))
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        Task { @MainActor in
            receiveManagerIsReady()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard let testService else {
            logger.error("Service was not available within \(#function)")
            return // TODO: respond
        }

        Task { @MainActor in
            await testService.logEvent(.receivedRead(request.characteristic.uuid)) // TODO: log response?
        }

        guard request.offset == 0 else {
            // we currently don't support that on the test device, no clue how it works. We don't need it.
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }


        // TODO: set request.data (as the response)
        // TODO: check: request.characteristic
        request.value = Data()
        peripheral.respond(to: request, withResult: .success) // TODO: test error code as well?
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else {
            logger.error("Received invalid write request from the central. Zero elements!")
            return
        }

        guard let testService else {
            logger.error("Service was not available within \(#function)")
            return // TODO: respond
        }

        for request in requests {
            guard let value = request.value else {
                continue
            }

            Task { @MainActor in
                await testService.logEvent(.receivedWrite(request.characteristic.uuid, value: value))
            }
        }

        guard requests.allSatisfy({ $0.offset == 0 }) else {
            // we currently don't support that on the test device, no clue how it works. We don't need it.
            peripheral.respond(to: first, withResult: .invalidOffset)
            return
        }

        // TODO: treat it as multi reuqest otherwise!
        // TODO: if you can't fulfill a single, don't fullfil any of them!

        // TODO: check offset?

        // TODO: just pass in the first request o the response(to:) method????
    }
}
