//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import NIO
import SpeziNumerics
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import XCTByteCoding
import XCTest


final class HealthThermometerTests: XCTestCase {
    func testMeasurementInterval() throws {
        try testIdentity(from: MeasurementInterval.noPeriodicMeasurement)
        try testIdentity(from: MeasurementInterval.duration(24))
    }

    func testTemperatureMeasurement() throws {
        let temp = MedFloat32(bitPattern: 0xAFAFAFAF) // 4 bytes for the medfloat
        let time = DateTime(hours: 13, minutes: 12, seconds: 12)

        try testIdentity(from: TemperatureMeasurement(temperature: temp, unit: .celsius))
        try testIdentity(from: TemperatureMeasurement(temperature: temp, unit: .fahrenheit))

        try testIdentity(from: TemperatureMeasurement(temperature: temp, unit: .celsius, timeStamp: time, temperatureType: .ear))
        try testIdentity(from: TemperatureMeasurement(temperature: temp, unit: .celsius, temperatureType: .ear))
        try testIdentity(from: TemperatureMeasurement(temperature: temp, unit: .celsius, timeStamp: time))
    }

    func testTemperatureType() throws {
        try testIdentity(from: TemperatureType.reserved)
        try testIdentity(from: TemperatureType.armpit)
        try testIdentity(from: TemperatureType.body)
        try testIdentity(from: TemperatureType.ear)
        try testIdentity(from: TemperatureType.finger)
        try testIdentity(from: TemperatureType.gastrointestinalTract)
        try testIdentity(from: TemperatureType.mouth)
        try testIdentity(from: TemperatureType.rectum)
        try testIdentity(from: TemperatureType.toe)
        try testIdentity(from: TemperatureType.tympanum)
    }

    func testTemperatureTypeStrings() {
        // swiftlint:disable line_length
        let expected = ["reserved", "armpit", "body", "ear", "finger", "gastrointestinalTract", "mouth", "rectum", "toe", "tympanum", "TemperatureType(rawValue: 23)"]
        let values = [TemperatureType.reserved, .armpit, .body, .ear, .finger, .gastrointestinalTract, .mouth, .rectum, .toe, .tympanum, .init(rawValue: 23)]
        // swiftlint:enable line_length
        XCTAssertEqual(values.map { $0.description }, expected)
    }
}
