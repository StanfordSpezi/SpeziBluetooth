//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@_spi(TestingSupport)
import SpeziBluetooth
import SpeziBluetoothServices
import Testing

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


@Suite("Device Testing Support")
struct BluetoothDeviceTestingSupportTests {
    @MainActor
    class Results<Value> {
        var received: [Value] = []
    }

    @Test("Automatic DeviceState Injection")
    func testDeviceStateInjectionArtificialValue() {
        let device = MockDevice()

        #expect(device.name == nil)
        #expect(device.state == .disconnected)
        #expect(device.advertisementData == .init()) // empty
        #expect(device.rssi == Int(UInt8.max))
        #expect(!device.nearby)

        let now = Date.now
        #expect(device.lastActivity >= now)
    }

    @Test("Manual DeviceState Injection")
    func testDeviceStateValueInjection() {
        let device = MockDevice()

        let id = UUID()
        device.$id.inject(id)

        #expect(device.id == id)
    }

    @MainActor
    @Test("DeviceState onChange Injection")
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

        #expect(results.received == [id1, id2])
    }

    func testDeviceActionInjection() async throws {
        let device = MockDevice()

        try await confirmation { confirmation in
            device.$connect.inject {
                try? await Task.sleep(for: .milliseconds(10))
                confirmation()
            }

            try await device.connect()
        }
    }

    @Test("Characteristic Value Injection")
    func testCharacteristicInjection() {
        let device = MockDevice()

        device.deviceInformation.$manufacturerName.inject("Hello World")

        #expect(device.deviceInformation.manufacturerName == "Hello World")
    }

    @MainActor
    @Test("Characteristic onChange Injection")
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

        #expect(results.received == [value1, value2, value3])
    }

    @Test("Characteristic Peripheral Simulation")
    func testCharacteristicPeripheralSimulation() async throws {
        let device = MockDevice()
        let service = device.deviceInformation

        let value1 = "Manufacturer1"
        let value2 = "Manufacturer2"
        let value3 = "Manufacturer3"

        service.$manufacturerName.enablePeripheralSimulation()
        service.$manufacturerName.inject(value1)

        let read = try await service.$manufacturerName.read()
        #expect(read == value1)

        try await service.$manufacturerName.write(value2)
        #expect(service.manufacturerName == value2)

        try await service.$manufacturerName.writeWithoutResponse(value3)
        #expect(service.manufacturerName == value3)
    }

    func testCharacteristicClosureInjection() async throws {
        let device = MockDevice()
        let service = device.deviceInformation

        let value1 = "Manufacturer1"
        let value2 = "Manufacturer2"
        let value3 = "Manufacturer3"

        service.$manufacturerName.onRead {
            value1
        }

        let read = try await service.$manufacturerName.read()
        #expect(read == value1)

        try await confirmation { confirmation in
            service.$manufacturerName.onWrite { value, type in
                guard case .withResponse = type else {
                    Issue.record("Unexpected response type: \(type)")
                    return
                }

                #expect(value == value2)
                confirmation()
            }

            try await service.$manufacturerName.write(value2)
        }

        try await confirmation { confirmation in
            service.$manufacturerName.onWrite { value, type in
                guard case .withoutResponse = type else {
                    Issue.record("Unexpected response type: \(type)")
                    return
                }

                #expect(value == value3)
                confirmation()
            }

            try await service.$manufacturerName.writeWithoutResponse(value3)
        }
    }
}
