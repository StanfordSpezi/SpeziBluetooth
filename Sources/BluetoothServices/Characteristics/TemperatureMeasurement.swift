//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIO


/// A temperature measurement.
///
/// Refer to GATT Specification Supplement, 3.216 Temperature Measurement.
public struct TemperatureMeasurement {
    /// The temperature value encoded as `medfloat32`.
    public enum Value {
        /// The temperature value in celsius.
        case celsius(_ medfloat32: Data) // TODO: Support medfloat32
        /// The temperature value in fahrenheit.
        case fahrenheit(_ medfloat32: Data)

        var data: Data {
            switch self {
            case let .fahrenheit(data):
                data
            case let .celsius(data):
                data
            }
        }
    }

    /// The temperature value encoded as a `medfloat32`.
    public let value: Value
    /// The timestamp of the recording.
    public let timeStamp: DateTime?
    /// The location of the temperature measurement.
    public let temperatureType: TemperatureType?


    /// Create a new temperature measurement.
    /// - Parameters:
    ///   - value: The measurement value.
    ///   - timeStamp: The timestamp of the measurement.
    ///   - temperatureType: The type of the measurement.
    public init(value: Value, timeStamp: DateTime? = nil, temperatureType: TemperatureType? = nil) {
        self.value = value
        self.timeStamp = timeStamp
        self.temperatureType = temperatureType
        assert(value.data.count == 4, "medFloat32 must be of length 4. Found \(value.data.count) bytes!")
    }
}


extension TemperatureMeasurement {
    private enum FlagsField { // TODO: optionset???
        static let isFahrenheitTemperature: UInt8 = 0x01
        static let isTimeStampPresent: UInt8 = 0x02
        static let isTemperatureTypePresent: UInt8 = 0x04
    }
}


// TODO: Sendable conformance everywhere!
extension TemperatureMeasurement.Value: Equatable {}


extension TemperatureMeasurement: Equatable {}


extension TemperatureMeasurement: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let flags = UInt8(from: &byteBuffer, preferredEndianness: endianness),
              let medFloat32 = byteBuffer.readData(length: 4) else {
            return nil
        }

        let measurement: Value
        var timeStamp: DateTime?
        var temperatureType: TemperatureType?

        if flags & FlagsField.isFahrenheitTemperature > 0 {
            measurement = .fahrenheit(medFloat32)
        } else {
            measurement = .celsius(medFloat32)
        }

        if flags & FlagsField.isTimeStampPresent > 0 {
            guard let dateTime = DateTime(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            timeStamp = dateTime
        }

        if flags & FlagsField.isTemperatureTypePresent > 0 {
            guard let type = TemperatureType(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            temperatureType = type
        }

        self.init(value: measurement, timeStamp: timeStamp, temperatureType: temperatureType)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        let flagsIndex = byteBuffer.writerIndex
        var flags: UInt8 = 0

        flags.encode(to: &byteBuffer, preferredEndianness: endianness) // write for now

        switch value {
        case let .fahrenheit(data):
            flags |= FlagsField.isFahrenheitTemperature
            data.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .celsius(data):
            data.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        if let timeStamp {
            flags |= FlagsField.isTimeStampPresent
            timeStamp.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        if let temperatureType {
            flags |= FlagsField.isTemperatureTypePresent
            temperatureType.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        byteBuffer.setInteger(flags, at: flagsIndex) // finally update the flags field
    }
}
