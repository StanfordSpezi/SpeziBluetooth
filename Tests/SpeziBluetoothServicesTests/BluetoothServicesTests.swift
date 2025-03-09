//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCodingTesting
import NIOCore
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import Testing


@Suite("Bluetooth Services")
struct BluetoothServicesTests {
    @Test("Services init")
    func testServices() {
        _ = TestService()
        _ = HealthThermometerService()
        _ = DeviceInformationService()
        _ = WeightScaleService()
        _ = BloodPressureService()
        _ = BatteryService()
        _ = CurrentTimeService()
        _ = PulseOximeterService()
    }

    @Test("BT UUID")
    func testUUID() {
        #expect(BTUUID.toCustomShort(.testService) == "F001")
    }

    @Test("Event Log")
    func testEventLog() throws {
        try testIdentity(from: EventLog.none)
        try testIdentity(from: EventLog.subscribedToNotification(.eventLogCharacteristic))
        try testIdentity(from: EventLog.unsubscribedToNotification(.eventLogCharacteristic))
        try testIdentity(from: EventLog.receivedRead(.readStringCharacteristic))
        try testIdentity(from: EventLog.receivedWrite(.writeStringCharacteristic, value: "Hello World".encode()))
    }
}
