//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziBluetooth
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
}


final class BluetoothDeviceTestingSupportTests: XCTestCase {
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
        @MainActor
        class Results {
            var received: [UUID] = []
        }
        let device = MockDevice()

        let id1 = UUID()
        let id2 = UUID()

        device.$id.enableSubscriptions()
        device.$id.inject(id1)

        let results = Results()

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
}
