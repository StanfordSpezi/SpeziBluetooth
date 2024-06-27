//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import NIO
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import XCTByteCoding
import XCTest


final class BluetoothServicesTests: XCTestCase {
    func testServices() async throws {
        _ = TestService()
        _ = HealthThermometerService()
        _ = DeviceInformationService()
        _ = WeightScaleService()
        _ = BloodPressureService()
        _ = BatteryService()
        _ = CurrentTimeService()
    }

    func testUUID() {
        XCTAssertEqual(CBUUID.toCustomShort(.testService), "F001")
    }

    func testEventLog() throws {
        try testIdentity(from: EventLog.none)
        try testIdentity(from: EventLog.subscribedToNotification(.eventLogCharacteristic))
        try testIdentity(from: EventLog.unsubscribedToNotification(.eventLogCharacteristic))
        try testIdentity(from: EventLog.receivedRead(.readStringCharacteristic))
        try testIdentity(from: EventLog.receivedWrite(.writeStringCharacteristic, value: "Hello World".encode()))
    }
}
