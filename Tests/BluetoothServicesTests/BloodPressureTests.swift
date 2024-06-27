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


final class BloodPressureTests: XCTestCase {
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
}
