//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO
import SpeziBluetooth


/// Date Time characteristic to represent date and time.
///
/// Refer to GATT Specification Supplement, 3.70 Date Time
public struct DateTime {
    public enum Month: UInt8 {
        case unknown
        case january
        case february
        case march
        case april
        case mai
        case june
        case july
        case august
        case september
        case october
        case november
        case december
    }

    /// Year as defined by the Gregorian calendar.
    ///
    /// Valid range 1582 to 9999.
    /// A value of 0 means that the year is not known. All other values are Reserved for Future Use.
    public let year: UInt16
    /// Month of the year as defined by the Gregorian calendar.
    ///
    /// Valid range 1 (January) to 12 (December).
    /// A value of 0 means that the month is not known.
    public let month: Month
    /// Day of the month as defined by the Gregorian calendar.
    ///
    /// Valid range 1 to 31.
    /// A value of 0 means that the day of month is not known.
    public let day: UInt8
    /// Number of hours past midnight.
    ///
    /// Valid range 0 to 23.
    public let hours: UInt8
    /// Number of minutes since the start of the hour.
    ///
    /// Valid range 0 to 59.
    public let minutes: UInt8
    /// Number of seconds since the start of the minute.
    ///
    /// Valid range 0 to 59.
    public let seconds: UInt8


    public init(year: UInt16, month: Month, day: UInt8, hours: UInt8, minutes: UInt8, seconds: UInt8) {
        self.year = year
        self.month = month
        self.day = day
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}

extension DateTime.Month: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let value = UInt8(from: &byteBuffer) else {
            return nil
        }

        self.init(rawValue: value)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension DateTime: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let year = UInt16(from: &byteBuffer),
              let month = Month(from: &byteBuffer),
              let day = UInt8(from: &byteBuffer),
              let hours = UInt8(from: &byteBuffer),
              let minutes = UInt8(from: &byteBuffer),
              let seconds = UInt8(from: &byteBuffer) else {
            return nil
        }

        self.init(year: year, month: month, day: day, hours: hours, minutes: minutes, seconds: seconds)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        year.encode(to: &byteBuffer)
        month.encode(to: &byteBuffer)
        day.encode(to: &byteBuffer)
        hours.encode(to: &byteBuffer)
        minutes.encode(to: &byteBuffer)
        seconds.encode(to: &byteBuffer)
    }
}