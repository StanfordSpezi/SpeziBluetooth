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


@Suite("WeightMeasurement Service")
struct WeightMeasurementTests {
    @Test("WeightMeasurement")
    func testWeightMeasurement() throws {
        let time = DateTime(hours: 13, minutes: 12, seconds: 12)

        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si))
        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si, timeStamp: time))
        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si, timeStamp: time, userId: 23))
        try testIdentity(from: WeightMeasurement(weight: 123, unit: .si, additionalInfo: .init(bmi: 230, height: 1760)))
    }

    @Test("WeightMeasurement Resolutions")
    func testWeightMeasurementResolutions() throws {
        func weightOf(_ weight: UInt16, resolution: WeightScaleFeature.WeightResolution, unit: WeightMeasurement.Unit = .si) -> Double {
            WeightMeasurement(weight: weight, unit: unit)
                .weight(of: resolution)
        }

        func heightOf(_ height: UInt16, resolution: WeightScaleFeature.HeightResolution, unit: WeightMeasurement.Unit = .si) -> Double? {
            WeightMeasurement(weight: 120, unit: unit, additionalInfo: .init(bmi: 230, height: height))
                .height(of: resolution)
        }

        #expect(weightOf(120, resolution: .unspecified) == 0.6)
        #expect(weightOf(120, resolution: .resolution5g) == 0.6)
        #expect(weightOf(120, resolution: .resolution10g) == 1.2)
        #expect(weightOf(120, resolution: .resolution20g) == 2.4)
        #expect(weightOf(120, resolution: .resolution50g) == 6)
        #expect(weightOf(120, resolution: .resolution100g) == 12)
        #expect(weightOf(120, resolution: .resolution200g) == 24)
        #expect(weightOf(120, resolution: .resolution500g) == 60)

        #expect(weightOf(120, resolution: .unspecified, unit: .imperial) == 1.2)
        #expect(weightOf(120, resolution: .resolution5g, unit: .imperial) == 1.2)
        #expect(weightOf(120, resolution: .resolution10g, unit: .imperial) == 2.4)
        #expect(weightOf(120, resolution: .resolution20g, unit: .imperial) == 6)
        #expect(weightOf(120, resolution: .resolution50g, unit: .imperial) == 12)
        #expect(weightOf(120, resolution: .resolution100g, unit: .imperial) == 24)
        #expect(weightOf(120, resolution: .resolution200g, unit: .imperial) == 60)
        #expect(weightOf(120, resolution: .resolution500g, unit: .imperial) == 120)

        #expect(heightOf(1700, resolution: .unspecified) == 1.7)
        #expect(heightOf(1700, resolution: .resolution1mm) == 1.7)
        #expect(heightOf(1700, resolution: .resolution5mm) == 8.5)
        #expect(heightOf(1700, resolution: .resolution10mm) == 17)

        #expect(heightOf(60, resolution: .unspecified, unit: .imperial) == 6)
        #expect(heightOf(60, resolution: .resolution1mm, unit: .imperial) == 6)
        #expect(heightOf(60, resolution: .resolution5mm, unit: .imperial) == 30)
        #expect(heightOf(60, resolution: .resolution10mm, unit: .imperial) == 60)
    }

    @Test("WeightScaleFeature")
    func testWeightScaleFeature() throws {
        let features: WeightScaleFeature = [
            .bmiSupported,
            .multipleUsersSupported,
            .timeStampSupported
        ]

        #expect(features.contains(.bmiSupported))
        #expect(features.contains(.multipleUsersSupported))
        #expect(features.contains(.timeStampSupported))

        try testIdentity(from: features)
        try testIdentity(from: WeightScaleFeature(weightResolution: .resolution20g, heightResolution: .resolution10mm))
        try testIdentity(from: WeightScaleFeature(
            weightResolution: .resolution20g,
            heightResolution: .resolution10mm,
            options: .bmiSupported,
            .multipleUsersSupported
        ))

        let features2 = WeightScaleFeature(weightResolution: .resolution20g, heightResolution: .resolution5mm, options: .bmiSupported)
        #expect(features2.weightResolution == .resolution20g)
        #expect(features2.heightResolution == .resolution5mm)
        #expect(features2.contains(.bmiSupported))
        #expect(!features2.contains(.multipleUsersSupported))
        #expect(!features2.contains(.timeStampSupported))
    }

    @Test("WeightScaleFeature Description")
    func testWeightScaleFeatureStrings() {
        let features: WeightScaleFeature = [
            .bmiSupported,
            .multipleUsersSupported,
            .timeStampSupported
        ]

        #expect(features.description == "WeightScaleFeature(weightResolution: WeightResolution(rawValue: 0), heightResolution: HeightResolution(rawValue: 0), options: timeStampSupported, multipleUsersSupported, bmiSupported)")
        // swiftlint:disable:previous line_length
        #expect(features.debugDescription == "WeightScaleFeature(rawValue: 0x07)")
    }
}
