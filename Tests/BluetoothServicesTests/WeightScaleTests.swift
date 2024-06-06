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


final class WeightMeasurementTests: XCTestCase {
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

        let features2 = WeightScaleFeature(weightResolution: .resolution20g, heightResolution: .resolution5mm, options: .bmiSupported)
        XCTAssertEqual(features2.weightResolution, .resolution20g)
        XCTAssertEqual(features2.heightResolution, .resolution5mm)
        XCTAssertTrue(features2.contains(.bmiSupported))
        XCTAssertFalse(features2.contains(.multipleUsersSupported))
        XCTAssertFalse(features2.contains(.timeStampSupported))
    }
}
