//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO
import SpeziNumerics
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import XCTByteCoding
import XCTest


final class PLXTests: XCTestCase {
    func testVerySimpleMeasurementCoding() throws {
        let measurement = PLXContinuousMeasurement(oxygenSaturation: 100, pulseRate: 90)
        try testIdentity(from: measurement)
        XCTAssertEqual(measurement.encode(), Data([0, 232, 243, 132, 243]))
        XCTAssertEqual(PLXContinuousMeasurement(data: Data([0, 100, 0, 90, 0])), measurement)
    }
    
    func testSimpleMeasurementCoding() throws {
        let data = Data([28, 95, 0, 90, 0, 32, 0, 0, 0, 0, 87, 240])
        let measurement = try XCTUnwrap(PLXContinuousMeasurement(data: data))
        XCTAssertEqual(PLXContinuousMeasurement(data: measurement.encode()), measurement)
        XCTAssertEqual(measurement, PLXContinuousMeasurement(
            oxygenSaturation: 95,
            pulseRate: 90,
            measurementStatus: .measurementIsOngoing,
            deviceAndSensorStatus: [],
            pulseAmplitudeIndex: 87e-1
        ))
        try testIdentity(from: measurement)
        XCTAssertEqual(measurement.encode(), data)
        XCTAssertEqual(PLXContinuousMeasurement(data: data), measurement)
    }
    
    
    func testFullMeasurementCoding() throws {
        let measurement = PLXContinuousMeasurement(
            oxygenSaturation: 99,
            pulseRate: 97,
            oxygenSaturationFast: 97,
            pulseRateFast: 137,
            oxygenSaturationSlow: 98,
            pulseRateSlow: 69,
            measurementStatus: [.measurementIsOngoing, .fullyQualifiedData],
            deviceAndSensorStatus: [],
            pulseAmplitudeIndex: 89e-1
        )
        try testIdentity(from: measurement)
        let data = Data([31, 222, 243, 202, 243, 202, 243, 90, 245, 212, 243, 178, 242, 32, 1, 0, 0, 0, 122, 227])
        XCTAssertEqual(measurement.encode(), data)
        XCTAssertEqual(PLXContinuousMeasurement(data: data), measurement)
    }
    
    
    func testSpotCheckMeasurementCoding() throws {
        let measurement = PLXSpotCheckMeasurement(
            oxygenSaturation: 94,
            pulseRate: 147,
            timestamp: DateTime(year: 2024, month: .november, day: 29, hours: 23, minutes: 08, seconds: 57),
            measurementStatus: [.measurementIsOngoing, .questionableMeasurementDetected],
            deviceAndSensorStatus: [.equipmentMalfunctionDetected, .lowPerfusionDetected],
            pulseAmplitudeIndex: 87e-1
        )
        try testIdentity(from: measurement)
        let data = Data([15, 172, 243, 190, 245, 232, 7, 11, 29, 23, 8, 57, 32, 64, 34, 0, 0, 102, 227])
        XCTAssertEqual(measurement.encode(), data)
        XCTAssertEqual(PLXSpotCheckMeasurement(data: data), measurement)
    }
    
    
    func testPLXFeaturesCoding() throws {
        let features = PLXFeatures(
            supportedFeatures: [.hasMeasurementStatusSupport, .hasDeviceAndSensorStatusSupport, .hasSpO2PRSlowSupport, .supportsMultipleBonds],
            measurementStatusSupport: [.calibrationOngoing, .earlyEstimatedData],
            deviceAndSensorStatusSupport: [.nonpulsatileSignalDetected, .questionablePulseDetected]
        )
        try testIdentity(from: features)
        let data = Data([163, 0, 64, 16, 128, 1, 0])
        XCTAssertEqual(features.encode(), data)
        XCTAssertEqual(PLXFeatures(data: data), features)
    }
}
