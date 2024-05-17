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


/// Date and time information.
///
/// Refer to GATT Specification Supplement, 3.70 Date Time.
public struct DateTime {
    /// The month.
    public struct Month: RawRepresentable {
        /// Unknown month.
        public static let unknown = Month(rawValue: 0)
        /// The month January.
        public static let january = Month(rawValue: 1)
        /// The month February.
        public static let february = Month(rawValue: 2)
        /// The month March.
        public static let march = Month(rawValue: 3)
        /// The month April.
        public static let april = Month(rawValue: 4)
        /// The month Mai.
        public static let mai = Month(rawValue: 5)
        /// The month June.
        public static let june = Month(rawValue: 6)
        /// The month July.
        public static let july = Month(rawValue: 7)
        /// The month August.
        public static let august = Month(rawValue: 8)
        /// The month September.
        public static let september = Month(rawValue: 9)
        /// The month October.
        public static let october = Month(rawValue: 10)
        /// The month November.
        public static let november = Month(rawValue: 11)
        /// The month December.
        public static let december = Month(rawValue: 12)

        public let rawValue: UInt8


        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
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


extension DateTime {
    /// The date components representation for the date and time.
    public var dateComponents: DateComponents {
        var components = DateComponents()

        // value of zero signals unknown
        if year > 0 {
            components.year = Int(year)
        }
        if month.rawValue > 0 {
            components.month = Int(month.rawValue)
        }
        if day > 0 {
            components.day = Int(day)
        }

        components.hour = Int(hours)
        components.minute = Int(minutes)
        components.second = Int(seconds)

        return components
    }


    /// Convert to Swift Date representation.
    ///
    /// Uses the current `Calendar`.
    /// Returns `nil` if a date with matching components couldn't be found.
    public var date: Date? {
        Calendar.current.date(from: dateComponents)
    }


    /// Initialize date time from date components.
    ///
    /// - Note: Returns `nil` if not all required date components (`hour`, `minute`, `second`) are
    ///     present. Date components `year`, `month` and `day` are optional but required to encode a date information.
    /// - Parameter components: The Swift Date Components.
    public init?(from components: DateComponents) {
        guard let hours = components.hour,
              let minutes = components.minute,
              let seconds = components.second else {
            return nil
        }

        let year = components.year.map(UInt16.init) ?? 0
        let month = components.month.map(UInt8.init) ?? 0
        let day = components.day.map(UInt8.init) ?? 0

        self.init(year: year, month: Month(rawValue: month), day: day, hours: UInt8(hours), minutes: UInt8(minutes), seconds: UInt8(seconds))
    }

    /// Initialize date time from a date and current `Calendar`.
    /// - Parameter date: The date to initialize from.
    public init(from date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .year, .month, .day], from: date)

        // we know that date components are present, so force-unwrapping is fine
        self.init(from: components)! // swiftlint:disable:this force_unwrapping
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
