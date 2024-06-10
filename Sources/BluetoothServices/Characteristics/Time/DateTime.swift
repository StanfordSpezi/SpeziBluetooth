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
    /// We reuse the byte representation from Date of Birth.
    private let date: DateOfBirth

    /// Year as defined by the Gregorian calendar.
    ///
    /// Valid range 1582 to 9999.
    /// A value of 0 means that the year is not known. All other values are Reserved for Future Use.
    public var year: UInt16 {
        date.year
    }

    /// Month of the year as defined by the Gregorian calendar.
    ///
    /// Valid range 1 (January) to 12 (December).
    /// A value of 0 means that the month is not known.
    public var month: Month {
        date.month
    }

    /// Day of the month as defined by the Gregorian calendar.
    ///
    /// Valid range 1 to 31.
    /// A value of 0 means that the day of month is not known.
    public var day: UInt8 {
        date.day
    }

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
        self.init(date: DateOfBirth(year: year, month: month, day: day), hours: hours, minutes: minutes, seconds: seconds)
    }

    fileprivate init(date: DateOfBirth, hours: UInt8, minutes: UInt8, seconds: UInt8) {
        self.date = date
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}


extension DateTime {
    /// The date components representation for the date and time.
    public var dateComponents: DateComponents {
        var components = date.dateComponents

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
        // TODO: update

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


extension DateTime: Hashable, Sendable {}


extension DateTime: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let date = DateOfBirth(from: &byteBuffer, preferredEndianness: endianness),
              let hours = UInt8(from: &byteBuffer, preferredEndianness: endianness),
              let minutes = UInt8(from: &byteBuffer, preferredEndianness: endianness),
              let seconds = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.init(date: date, hours: hours, minutes: minutes, seconds: seconds)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        date.encode(to: &byteBuffer, preferredEndianness: endianness)
        hours.encode(to: &byteBuffer, preferredEndianness: endianness)
        minutes.encode(to: &byteBuffer, preferredEndianness: endianness)
        seconds.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
