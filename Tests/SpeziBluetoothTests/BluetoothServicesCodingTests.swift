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

    func testWeightMeasurement() throws {
        let time = DateTime(hours: 13, minutes: 12, seconds: 12)

        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si))
        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si, timeStamp: time))
        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si, timeStamp: time, userId: 23))
        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si, additionalInfo: .init(bmi: 230, height: 1760)))
    }

    func testWeightMeasurementResolutions() throws {
        func weightOf(_ weight: UInt16, resolution: WeightScaleFeature.WeightResolution, unit: WeightMeasurement.Unit = .si) -> Double {
            WeightMeasurement(weight: weight, unit: unit)
                .weight(of: resolution)
        }

        func heightOf(_ height: UInt16, resolution: WeightScaleFeature.HeightResolution, unit: WeightMeasurement.Unit = .si) -> Double? {
            WeightMeasurement(weight: 120, unit: unit, additionalInfo: .init(bmi: 230, height: height))
                .height(of: resolution)
        }

        XCTAssertEqual(weightOf(120, resolution: .unspecified), 0.6)
        XCTAssertEqual(weightOf(120, resolution: .resolution5g), 0.6)
        XCTAssertEqual(weightOf(120, resolution: .resolution10g), 1.2)
        XCTAssertEqual(weightOf(120, resolution: .resolution20g), 2.4)
        XCTAssertEqual(weightOf(120, resolution: .resolution50g), 6)
        XCTAssertEqual(weightOf(120, resolution: .resolution100g), 12)
        XCTAssertEqual(weightOf(120, resolution: .resolution200g), 24)
        XCTAssertEqual(weightOf(120, resolution: .resolution500g), 60)

        XCTAssertEqual(weightOf(120, resolution: .unspecified, unit: .imperial), 1.2)
        XCTAssertEqual(weightOf(120, resolution: .resolution5g, unit: .imperial), 1.2)
        XCTAssertEqual(weightOf(120, resolution: .resolution10g, unit: .imperial), 2.4)
        XCTAssertEqual(weightOf(120, resolution: .resolution20g, unit: .imperial), 6)
        XCTAssertEqual(weightOf(120, resolution: .resolution50g, unit: .imperial), 12)
        XCTAssertEqual(weightOf(120, resolution: .resolution100g, unit: .imperial), 24)
        XCTAssertEqual(weightOf(120, resolution: .resolution200g, unit: .imperial), 60)
        XCTAssertEqual(weightOf(120, resolution: .resolution500g, unit: .imperial), 120)

        XCTAssertEqual(heightOf(1700, resolution: .unspecified), 1.7)
        XCTAssertEqual(heightOf(1700, resolution: .resolution1mm), 1.7)
        XCTAssertEqual(heightOf(1700, resolution: .resolution5mm), 8.5)
        XCTAssertEqual(heightOf(1700, resolution: .resolution10mm), 17)

        XCTAssertEqual(heightOf(60, resolution: .unspecified, unit: .imperial), 6)
        XCTAssertEqual(heightOf(60, resolution: .resolution1mm, unit: .imperial), 6)
        XCTAssertEqual(heightOf(60, resolution: .resolution5mm, unit: .imperial), 30)
        XCTAssertEqual(heightOf(60, resolution: .resolution10mm, unit: .imperial), 60)
    }

    func testWeightScaleFeature() throws {
        let features: WeightScaleFeature = [
            .bmiSupported,
            .multipleUsersSupported,
            .timeStampSupported
        ]

        XCTAssertTrue(features.contains(.bmiSupported))
        XCTAssertTrue(features.contains(.multipleUsersSupported))
        XCTAssertTrue(features.contains(.timeStampSupported))

        try testIdentity(from: features)
        try testIdentity(from: WeightScaleFeature(weightResolution: .resolution20g, heightResolution: .resolution10mm))
        try testIdentity(from: WeightScaleFeature(
            weightResolution: .resolution20g,
            heightResolution: .resolution10mm,
            options: .bmiSupported,
            .multipleUsersSupported
        ))
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
