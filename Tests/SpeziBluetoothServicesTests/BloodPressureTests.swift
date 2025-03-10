//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCodingTesting
import CoreBluetooth
import NIOCore
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import Testing


@Suite("Blood Pressure Service")
struct BloodPressureTests {
    @Test("Blood Pressure Measurement")
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

    @Test("Immediate Cuff Pressure")
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

    @Test("Blood Pressure Feature")
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

        #expect(features.contains(.bodyMovementDetectionSupported))
        #expect(features.contains(.cuffFitDetectionSupported))
        #expect(features.contains(.irregularPulseDetectionSupported))
        #expect(features.contains(.pulseRateRangeDetectionSupported))
        #expect(features.contains(.measurementPositionDetectionSupported))
        #expect(features.contains(.multipleBondsSupported))
        #expect(features.contains(.e2eCrcSupported))
        #expect(features.contains(.userDataServiceSupported))
        #expect(features.contains(.userFacingTimeSupported))

        let features2: BloodPressureFeature = [BloodPressureFeature.bodyMovementDetectionSupported, .irregularPulseDetectionSupported]
        let features3: BloodPressureFeature = [BloodPressureFeature.bodyMovementDetectionSupported, .userFacingTimeSupported]

        try testIdentity(from: features)
        try testIdentity(from: features2)
        try testIdentity(from: features3)
    }

    @Test("Blood Pressure Feature Strings")
    func testBloodPressureFeatureStrings() {
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

        // swiftlint:disable:next line_length
        #expect(features.description == "[bodyMovementDetectionSupported, cuffFitDetectionSupported, irregularPulseDetectionSupported, pulseRateRangeDetectionSupported, measurementPositionDetectionSupported, multipleBondsSupported, e2eCrcSupported, userDataServiceSupported, userFacingTimeSupported]")
        #expect(features.debugDescription == "BloodPressureFeature(rawValue: 0x1FF)")
    }

    @Test("Blood Pressure Status Strings")
    func testBloodPressureStatusStrings() {
        let status: BloodPressureMeasurement.Status = [
            .bodyMovementDetected,
            .looseCuffFit,
            .irregularPulse,
            .pulseRateExceedsUpperLimit,
            .pulseRateBelowLowerLimit,
            .improperMeasurementPosition
        ]

        // swiftlint:disable:next line_length
        #expect(status.description == "[bodyMovementDetected, looseCuffFit, irregularPulse, pulseRateExceedsUpperLimit, pulseRateBelowLowerLimit, improperMeasurementPosition]")
        #expect(status.debugDescription == "Status(rawValue: 0x3F)")
    }
}
