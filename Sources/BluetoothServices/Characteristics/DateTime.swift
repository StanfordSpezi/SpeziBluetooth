//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIO


/// Date Time characteristic to represent date and time.
///
/// Refer to GATT Specification Supplement, 3.70 Date Time.
public struct DateTime {
    public enum Month: UInt8 {
        /// Unknown month.
        case unknown
        /// The month January.
        case january
        /// The month February.
        case february
        /// The month March.
        case march
        /// The month April.
        case april
        /// The month Mai.
        case mai
        /// The month June.
        case june
        /// The month July.
        case july
        /// The month August.
        case august
        /// The month September.
        case september
        /// The month October.
        case october
        /// The month November.
        case november
        /// The month December.
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


    /// Create a new Date Time.
    /// - Parameters:
    ///   - year: The year.
    ///   - month: The month.
    ///   - day: The day.
    ///   - hours: The hours.
    ///   - minutes: The minutes.
    ///   - seconds: The seconds.
    public init(year: UInt16 = 0, month: Month = .unknown, day: UInt8 = 0, hours: UInt8, minutes: UInt8, seconds: UInt8) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.year = year
        self.month = month
        self.day = day
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}


extension DateTime.Month: Hashable, Sendable {}


extension DateTime: Hashable, Sendable {}


extension DateTime.Month: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let value = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.init(rawValue: value)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension DateTime: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let year = UInt16(from: &byteBuffer, preferredEndianness: endianness),
              let month = Month(from: &byteBuffer, preferredEndianness: endianness),
              let day = UInt8(from: &byteBuffer, preferredEndianness: endianness),
              let hours = UInt8(from: &byteBuffer, preferredEndianness: endianness),
              let minutes = UInt8(from: &byteBuffer, preferredEndianness: endianness),
              let seconds = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.init(year: year, month: month, day: day, hours: hours, minutes: minutes, seconds: seconds)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        year.encode(to: &byteBuffer, preferredEndianness: endianness)
        month.encode(to: &byteBuffer, preferredEndianness: endianness)
        day.encode(to: &byteBuffer, preferredEndianness: endianness)
        hours.encode(to: &byteBuffer, preferredEndianness: endianness)
        minutes.encode(to: &byteBuffer, preferredEndianness: endianness)
        seconds.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
