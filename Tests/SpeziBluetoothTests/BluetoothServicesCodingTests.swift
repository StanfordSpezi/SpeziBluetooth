//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable @_spi(TestingSupport)
import BluetoothServices
import CoreBluetooth
import NIO
@testable @_spi(TestingSupport)
import SpeziBluetooth
import XCTBluetooth
import XCTest


final class BluetoothServicesTests: XCTestCase {
    func testDateTime() throws {
        try testIdentity(from: DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40))
        try testIdentity(from: DateTime(hours: 23, minutes: 50, seconds: 40))
    }

    func testMeasurementInterval() throws {
        try testIdentity(from: MeasurementInterval.noPeriodicMeasurement)
        try testIdentity(from: MeasurementInterval.duration(24))
    }

    func testTemperatureMeasurement() throws {
        let data = try XCTUnwrap(Data(hex: "0xAFAFAFAF")) // 4 bytes for the medfloat
        let time = DateTime(hours: 13, minutes: 12, seconds: 12)

        try testIdentity(from: TemperatureMeasurement(value: .celsius(data)))
        try testIdentity(from: TemperatureMeasurement(value: .fahrenheit(data)))

        try testIdentity(from: TemperatureMeasurement(value: .celsius(data), timeStamp: time, temperatureType: .ear))
        try testIdentity(from: TemperatureMeasurement(value: .celsius(data), temperatureType: .ear))
        try testIdentity(from: TemperatureMeasurement(value: .celsius(data), timeStamp: time))
    }

    func testTemperatureType() throws {
        for type in TemperatureType.allCases {
            try testIdentity(from: type)
        }
    }

    func testPnPID() throws {
        try testIdentity(from: VendorIDSource.bluetoothSIGAssigned)
        try testIdentity(from: VendorIDSource.usbImplementersForumAssigned)
        try testIdentity(from: VendorIDSource.reserved(23))

        try testIdentity(from: PnPID(vendorIdSource: .bluetoothSIGAssigned, vendorId: 24, productId: 1, productVersion: 56))
    }

    func testEventLog() throws {
        try testIdentity(from: EventLog.none)
        try testIdentity(from: EventLog.subscribedToNotification(.eventLogCharacteristic))
        try testIdentity(from: EventLog.unsubscribedToNotification(.eventLogCharacteristic))
        try testIdentity(from: EventLog.receivedRead(.readStringCharacteristic))
        try testIdentity(from: EventLog.receivedWrite(.writeStringCharacteristic, value: "Hello World".data(using: .utf8)!))
    }

    func testCharacteristics() async throws {
        _ = TestService()
        _ = HealthThermometerService()
        let info = DeviceInformationService()
        try await info.retrieveDeviceInformation()
    }

    func testUUID() {
        XCTAssertEqual(CBUUID.toCustomShort(.testService), "F001")
    }
}
