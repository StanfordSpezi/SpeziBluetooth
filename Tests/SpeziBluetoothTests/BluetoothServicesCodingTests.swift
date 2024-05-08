//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
@testable import BluetoothServices
import CoreBluetooth
import NIO
@_spi(TestingSupport)
@testable import SpeziBluetooth
import XCTByteCoding
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
        let data: UInt32 = 0xAFAFAFAF // 4 bytes for the medfloat
        let time = DateTime(hours: 13, minutes: 12, seconds: 12)

        try testIdentity(from: TemperatureMeasurement(temperature: data, unit: .celsius))
        try testIdentity(from: TemperatureMeasurement(temperature: data, unit: .fahrenheit))

        try testIdentity(from: TemperatureMeasurement(temperature: data, unit: .celsius, timeStamp: time, temperatureType: .ear))
        try testIdentity(from: TemperatureMeasurement(temperature: data, unit: .celsius, temperatureType: .ear))
        try testIdentity(from: TemperatureMeasurement(temperature: data, unit: .celsius, timeStamp: time))
    }

    func testBloodPressureMeasurement() throws {
        let time = DateTime(hours: 13, minutes: 12, seconds: 12)

        try testIdentity(from: BloodPressureMeasurement(systolic: 120.5, diastolic: 80.5, meanArterialPressure: 60, unit: .mmHg))
        try testIdentity(from: BloodPressureMeasurement(systolic: 120.5, diastolic: 80.5, meanArterialPressure: 60, unit: .kPa))

        try testIdentity(from: BloodPressureMeasurement(
            systolic: 120.5,
            diastolic: 80.5,
            meanArterialPressure: 60,
            unit: .mmHg,
            timeStamp: time,
            pulseRate: 54,
            userId: 0x67,
            measurementStatus: [.irregularPulse, .bodyMovementDetected]
        ))
    }

    func testIntermediateCuffPressure() throws {
        let time = DateTime(hours: 13, minutes: 12, seconds: 12)

        try testIdentity(from: IntermediateCuffPressure(currentCuffPressure: 56, unit: .mmHg))
        try testIdentity(from: IntermediateCuffPressure(currentCuffPressure: 56, unit: .kPa))

        try testIdentity(from: IntermediateCuffPressure(
            currentCuffPressure: 56,
            unit: .mmHg,
            timeStamp: time,
            pulseRate: 54,
            userId: 0x67,
            measurementStatus: [.irregularPulse, .bodyMovementDetected]
        ))
    }

    func testBloodPressureFeature() throws {
        let features: BloodPressureFeature = [
            .bodyMovementDetectionSupported,
            .cuffFitDetectionSupported,
            .irregularPulseDetectionSupported,
            .pulseRateRangeDetectionSupported,
            .measurementPositionDetectionSupported,
            .multipleBondsSupported,
            .e2eCrcSupported,
            .userDataServiceSupported,
            .userFacingTimeSupported
        ]

        XCTAssertTrue(features.contains(.bodyMovementDetectionSupported))
        XCTAssertTrue(features.contains(.cuffFitDetectionSupported))
        XCTAssertTrue(features.contains(.irregularPulseDetectionSupported))
        XCTAssertTrue(features.contains(.pulseRateRangeDetectionSupported))
        XCTAssertTrue(features.contains(.measurementPositionDetectionSupported))
        XCTAssertTrue(features.contains(.multipleBondsSupported))
        XCTAssertTrue(features.contains(.e2eCrcSupported))
        XCTAssertTrue(features.contains(.userDataServiceSupported))
        XCTAssertTrue(features.contains(.userFacingTimeSupported))

        let features2: BloodPressureFeature = [BloodPressureFeature.bodyMovementDetectionSupported, .irregularPulseDetectionSupported]
        let features3: BloodPressureFeature = [BloodPressureFeature.bodyMovementDetectionSupported, .userFacingTimeSupported]

        try testIdentity(from: features)
        try testIdentity(from: features2)
        try testIdentity(from: features3)
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
        try testIdentity(from: EventLog.receivedWrite(.writeStringCharacteristic, value: "Hello World".encode()))
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
