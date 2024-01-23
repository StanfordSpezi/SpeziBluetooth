//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import NIO
import SpeziBluetooth


public struct TemperatureMeasurement {
    public enum Value {
        case celsius(_ medfloat32: Data)
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

    public let value: Value
    public let timeStamp: DateTime?
    public let temperatureType: TemperatureType?


    public init(value: Value, timeStamp: DateTime? = nil, temperatureType: TemperatureType? = nil) {
        self.value = value
        self.timeStamp = timeStamp
        self.temperatureType = temperatureType
        assert(value.data.count == 4, "medFloat32 must be of length 4. Found \(value.data.count) bytes!")
    }
}


extension TemperatureMeasurement {
    private enum FlagsField {
        static let isFahrenheitTemperature: UInt8 = 0x01
        static let isTimeStampPresent: UInt8 = 0x02
        static let isTemperatureTypePresent: UInt8 = 0x04
    }
}


extension TemperatureMeasurement: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let flags = UInt8(from: &byteBuffer),
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
            guard let dateTime = DateTime(from: &byteBuffer) else {
                return nil
            }
            timeStamp = dateTime
        }

        if flags & FlagsField.isTemperatureTypePresent > 0 {
            guard let type = TemperatureType(from: &byteBuffer) else {
                return nil
            }
            temperatureType = type
        }

        self.init(value: measurement, timeStamp: timeStamp, temperatureType: temperatureType)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        let flagsIndex = byteBuffer.writerIndex
        var flags: UInt8 = 0

        flags.encode(to: &byteBuffer) // write for now

        switch value {
        case let .fahrenheit(data):
            flags |= FlagsField.isFahrenheitTemperature
            data.encode(to: &byteBuffer)
        case let .celsius(data):
            data.encode(to: &byteBuffer)
        }

        if let timeStamp {
            flags |= FlagsField.isTimeStampPresent
            timeStamp.encode(to: &byteBuffer)
        }

        if let temperatureType {
            flags |= FlagsField.isTemperatureTypePresent
            temperatureType.encode(to: &byteBuffer)
        }

        byteBuffer.setInteger(flags, at: flagsIndex) // finally update the flags field
    }
}
