//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import BluetoothServices
import CoreBluetooth
import OSLog
import SpeziBluetooth


@main
class TestPeripheral: NSObject, CBPeripheralManagerDelegate {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "TestPeripheral")
    private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth-peripheral", qos: .userInitiated)

    private var peripheralManager: CBPeripheralManager! // swiftlint:disable:this implicitly_unwrapped_optional

    private(set) var testService: TestService?
    private(set) var state: CBManagerState = .unknown

    @MainActor private var queuedUpdates: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: DispatchQueue.main)
    }

    static func main() async {
        let peripheral = TestPeripheral()
        peripheral.logger.info("Initialized")
        // while true {}

        var cont: CheckedContinuation<Void, Never>?
        await withCheckedContinuation { continuation in
            cont = continuation
        }
        cont?.resume() // silence warning
    }

    func startAdvertising() {
        guard let testService else {
            logger.error("Service was not available after starting advertising!")
            return
        }

        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [testService.service.uuid],
            CBAdvertisementDataLocalNameKey: "Spezi Peripheral"
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }

    @MainActor
    func updateValue<Value: ByteEncodable>(_ value: Value, for characteristic: CBMutableCharacteristic, for centrals: [CBCentral]? = nil) async {
        // swiftlint:disable:previous discouraged_optional_collection

        let data = value.encode()
        characteristic.value = data

        while !peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: centrals) {
            // if false is returned, queue is full and we need to wait for flush signal.
            await withCheckedContinuation { continuation in
                logger.warning("Peripheral update failed!")
                queuedUpdates.append(continuation)
            }
        }
    }

    @MainActor
    private func receiveManagerIsReady() {
        logger.debug("Received manager is ready.")
        let elements = queuedUpdates
        queuedUpdates.removeAll()

        for element in elements {
            element.resume()
        }
    }

    private func addServices() {
        peripheralManager.removeAllServices()

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
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }

        guard request.characteristic.service?.uuid == testService.service.uuid else {
            logger.error("Received request for unexpected service \(request.characteristic.service?.uuid)")
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }

        Task { @MainActor in
            await testService.logEvent(.receivedRead(request.characteristic.uuid))
        }

        guard request.offset == 0 else {
            logger.error("Characteristic read requested a non-zero offset \(request.offset) for \(request.characteristic.uuid)!")
            // we currently don't support that on the test device, no clue how it works. We don't need it.
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }

        Task { @MainActor in
            let result = testService.handleRead(for: request)
            peripheral.respond(to: request, withResult: result)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else {
            logger.error("Received invalid write request from the central. Zero elements!")
            return
        }

        guard let testService else {
            logger.error("Service was not available within \(#function)")
            peripheral.respond(to: first, withResult: .attributeNotFound)
            return
        }

        for request in requests {
            guard request.characteristic.service?.uuid == testService.service.uuid else {
                logger.error("Received request for unexpected service \(request.characteristic.service?.uuid)")
                peripheral.respond(to: first, withResult: .attributeNotFound)
                return
            }
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
            logger.error("Characteristic write requested a non-zero offset!")
            // we currently don't support that on the test device, no clue how it works. We don't need it.
            peripheral.respond(to: first, withResult: .invalidOffset)
            return
        }


        Task { @MainActor in
            // The following is mentioned in the docs:
            // Always respond with the first request.
            // Treat it as a multi request otherwise.
            // If you can't fulfill a single one, don't fulfill any of them (we are not exactly supporting the transactions part of that).
            for request in requests {
                let result = testService.handleWrite(for: request)

                if result != .success {
                    peripheral.respond(to: first, withResult: result)
                    return
                }
            }

            peripheral.respond(to: first, withResult: .success)
        }
    }
}
