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


class TestService {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "TestService")

    private weak var peripheral: TestPeripheral?
    let service: CBMutableService

    let eventLog: CBMutableCharacteristic
    /// We only provide the value.
    let readString: CBMutableCharacteristic
    /// We only receive a value.
    let writeString: CBMutableCharacteristic
    /// Bidirectional storage value.
    let readWriteString: CBMutableCharacteristic
    /// Reset peripheral state to default settings
    let reset: CBMutableCharacteristic

    private var readStringCount: UInt = 1
    private var readStringValue: String {
        defer {
            readStringCount += 1
        }
        return "Hello World (\(readStringCount))"
    }

    private var lastEvent: EventLog = .none
    private var readWriteStringValue: String

    init(peripheral: TestPeripheral) {
        self.peripheral = peripheral
        self.service = CBMutableService(type: .testService, primary: true)

        self.readWriteStringValue = ""

        self.eventLog = CBMutableCharacteristic(type: .eventLogCharacteristic, properties: [.indicate, .read], value: nil, permissions: [.readable])
        self.readString = CBMutableCharacteristic(type: .readStringCharacteristic, properties: [.read], value: nil, permissions: [.readable])
        self.writeString = CBMutableCharacteristic(type: .writeStringCharacteristic, properties: [.write], value: nil, permissions: [.writeable])
        self.readWriteString = CBMutableCharacteristic(
            type: .readWriteStringCharacteristic,
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )
        self.reset = CBMutableCharacteristic(type: .resetCharacteristic, properties: [.write], value: nil, permissions: [.writeable])

        service.characteristics = [eventLog, readString, writeString, readWriteString, reset]

        resetState()
    }

    private func resetState() {
        self.readStringCount = 1
        self.readWriteStringValue = "Hello Spezi"
    }


    @MainActor
    func logEvent(_ event: EventLog) async {
        guard let peripheral else {
            logger.error("Couldn't log event with missing peripheral!")
            return
        }

        logger.info("Logging event \(event)")
        self.lastEvent = event
        await peripheral.updateValue(event, for: eventLog)
    }

    @MainActor
    func handleRead(for request: CBATTRequest) -> CBATTError.Code {
        switch request.characteristic.uuid {
        case eventLog.uuid:
            request.value = self.lastEvent.encode()
        case writeString.uuid, reset.uuid:
            return .readNotPermitted
        case readString.uuid:
            let value = readStringValue
            request.value = value.encode()
        case readWriteString.uuid:
            request.value = readWriteStringValue.encode()
        default:
            return .attributeNotFound
        }

        return .success
    }

    @MainActor
    func handleWrite(for request: CBATTRequest) -> CBATTError.Code {
        guard let value = request.value else {
            return .attributeNotFound
        }

        switch request.characteristic.uuid {
        case eventLog.uuid, readString.uuid:
            return .writeNotPermitted
        case writeString.uuid:
            break // we don't store the value anywhere, so we can just discard it :)
        case reset.uuid:
            self.resetState()
        case readWriteString.uuid:
            guard let string = String(data: value) else {
                return .unlikelyError
            }
            readWriteStringValue = string
        default:
            return .attributeNotFound
        }

        return .success
    }
}
