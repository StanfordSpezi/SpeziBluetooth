//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziBluetooth
import SpeziBluetoothServices
import XCTest

final class MockDevice: BluetoothDevice, @unchecked Sendable {
    @DeviceState(\.id)
    var id
    @DeviceState(\.name)
    var name
    @DeviceState(\.state)
    var state
    @DeviceState(\.rssi)
    var rssi
    @DeviceState(\.advertisementData)
    var advertisementData
    @DeviceState(\.nearby)
    var nearby
    @DeviceState(\.lastActivity)
    var lastActivity


    @DeviceAction(\.connect)
    var connect

    @Service var deviceInformation = DeviceInformationService()
}


final class BluetoothDeviceTestingSupportTests: XCTestCase {
    @MainActor
    class Results<Value> {
        var received: [Value] = []
    }

    func testDeviceStateInjectionArtificialValue() {
        let device = MockDevice()

        XCTAssertNil(device.name)
        XCTAssertEqual(device.state, .disconnected)
        XCTAssertEqual(device.advertisementData, .init()) // empty
        XCTAssertEqual(device.rssi, Int(UInt8.max))
        XCTAssertFalse(device.nearby)

        let now = Date.now
        XCTAssert(device.lastActivity >= now)
    }

    func testDeviceStateValueInjection() {
        let device = MockDevice()

        let id = UUID()
        device.$id.inject(id)

        XCTAssertEqual(device.id, id)
    }

    @MainActor
    func testDeviceStateOnChangeInjection() async throws {
        let device = MockDevice()

        let id1 = UUID()
        let id2 = UUID()

        device.$id.enableSubscriptions()
        device.$id.inject(id1)

        let results = Results<UUID>()

        device.$id.onChange(initial: true) { @MainActor value in
            results.received.append(value)
        }

        device.$id.inject(id2)

        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(results.received, [id1, id2])
    }

    func testDeviceActionInjection() async throws {
        let device = MockDevice()

        let expectation = XCTestExpectation(description: "closure")

        device.$connect.inject {
            try? await Task.sleep(for: .milliseconds(10))
            expectation.fulfill()
        }

        await device.connect()

        await fulfillment(of: [expectation], timeout: 0.1)
    }

    func testCharacteristicInjection() {
        let device = MockDevice()

        device.deviceInformation.$manufacturerName.inject("Hello World")

        XCTAssertEqual(device.deviceInformation.manufacturerName, "Hello World")
    }

    @MainActor
    func testCharacteristicOnChangeInjection() async throws {
        let device = MockDevice()

        let service = device.deviceInformation

        let value1 = "Manufacturer1"
        let value2 = "Manufacturer2"
        let value3 = "Manufacturer3"

        service.$manufacturerName.enableSubscriptions()
        service.$manufacturerName.inject(value1)

        let results = Results<String>()

        service.$manufacturerName.onChange(initial: true) { @MainActor value in
            results.received.append(value)
        }

        service.$manufacturerName.inject(value2)

        try await Task.sleep(for: .milliseconds(50))
        service.$manufacturerName.inject(value3)

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(results.received, [value1, value2, value3])
    }

    func testCharacteristicPeripheralSimulation() async throws {
        let device = MockDevice()
        let service = device.deviceInformation

        let value1 = "Manufacturer1"
        let value2 = "Manufacturer2"
        let value3 = "Manufacturer3"

        service.$manufacturerName.enablePeripheralSimulation()
        service.$manufacturerName.inject(value1)

        let read = try await service.$manufacturerName.read()
        XCTAssertEqual(read, value1)

        try await service.$manufacturerName.write(value2)
        XCTAssertEqual(service.manufacturerName, value2)

        try await service.$manufacturerName.writeWithoutResponse(value3)
        XCTAssertEqual(service.manufacturerName, value3)
    }

    func testCharacteristicClosureInjection() async throws {
        let device = MockDevice()
        let service = device.deviceInformation

        let value1 = "Manufacturer1"
        let value2 = "Manufacturer2"
        let value3 = "Manufacturer3"

        let writeExpectation = XCTestExpectation(description: "write")
        let writeWithoutResponseExpectation = XCTestExpectation(description: "writeWithoutResponse")

        service.$manufacturerName.onRead {
            value1
        }
        service.$manufacturerName.onWrite { value, type in
            switch type {
            case .withResponse:
                XCTAssertEqual(value, value2)
                writeExpectation.fulfill()
            case .withoutResponse:
                XCTAssertEqual(value, value3)
                writeWithoutResponseExpectation.fulfill()
            }
        }

        let read = try await service.$manufacturerName.read()
        XCTAssertEqual(read, value1)

        try await service.$manufacturerName.write(value2)
        try await service.$manufacturerName.writeWithoutResponse(value3)

        await fulfillment(of: [writeExpectation, writeWithoutResponseExpectation], timeout: 0.1)
    }
}
