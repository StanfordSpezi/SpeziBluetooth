//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore


/// A temperature measurement.
///
/// Refer to GATT Specification Supplement, 3.216 Temperature Measurement.
public struct TemperatureMeasurement {
    fileprivate struct Flags: OptionSet {
        let rawValue: UInt8

        static let fahrenheitUnit = Flags(rawValue: 1 << 0)
        static let timeStampPresent = Flags(rawValue: 1 << 1)
        static let temperatureTypePresent = Flags(rawValue: 1 << 2)

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// The unit of a temperature measurement.
    public enum Unit: String {
        /// The temperature value is measured in celsius.
        case celsius
        /// The temperature value is measured in fahrenheit.
        case fahrenheit
    }

    /// The temperature value encoded as a `medfloat32`.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public let temperature: UInt32
    /// The unit of the temperature value .
    ///
    /// This property defined the unit of the ``temperature`` property.
    public let unit: Unit

    /// The timestamp of the recording.
    public let timeStamp: DateTime?
    /// The location of the temperature measurement.
    public let temperatureType: TemperatureType?


    /// Create a new temperature measurement.
    /// - Parameters:
    ///   - temperature: The measurement value as a medfloat32.
    ///   - unit: The unit of the temperature measurement.
    ///   - timeStamp: The timestamp of the measurement.
    ///   - temperatureType: The type of the measurement.
    public init(temperature: UInt32, unit: Unit, timeStamp: DateTime? = nil, temperatureType: TemperatureType? = nil) {
        self.temperature = temperature
        self.unit = unit
        self.timeStamp = timeStamp
        self.temperatureType = temperatureType
    }
}


extension TemperatureMeasurement.Unit: Sendable, Hashable {}


extension TemperatureMeasurement: Sendable, Hashable {}


extension TemperatureMeasurement.Flags: ByteCodable {
    init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt8(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}

extension TemperatureMeasurement: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let flags = Flags(from: &byteBuffer),
              let temperature = UInt32(from: &byteBuffer) else {
            return nil
        }

        self.temperature = temperature

        if flags.contains(.fahrenheitUnit) {
            self.unit = .fahrenheit
        } else {
            self.unit = .celsius
        }

        if flags.contains(.timeStampPresent) {
            guard let timeStamp = DateTime(from: &byteBuffer) else {
                return nil
            }
            self.timeStamp = timeStamp
        } else {
            self.timeStamp = nil
        }

        if flags.contains(.temperatureTypePresent) {
            guard let temperatureType = TemperatureType(from: &byteBuffer) else {
                return nil
            }
            self.temperatureType = temperatureType
        } else {
            self.temperatureType = nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        var flags: Flags = []

        // write empty flags field for now to move writer index
        let flagsIndex = byteBuffer.writerIndex
        flags.encode(to: &byteBuffer)

        temperature.encode(to: &byteBuffer)

        if case .fahrenheit = unit {
            flags.insert(.fahrenheitUnit)
        }

        if let timeStamp {
            flags.insert(.timeStampPresent)
            timeStamp.encode(to: &byteBuffer)
        }

        if let temperatureType {
            flags.insert(.temperatureTypePresent)
            temperatureType.encode(to: &byteBuffer)
        }

        byteBuffer.setInteger(flags.rawValue, at: flagsIndex) // finally update the flags field
    }
}


extension TemperatureMeasurement.Unit: Codable {}


extension TemperatureMeasurement: Codable {}
