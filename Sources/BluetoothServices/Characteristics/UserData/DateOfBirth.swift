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


/// Date of Birth of a user.
///
/// Refer to GATT Specification Supplement, 3.68 Date of Birth.
public struct DateOfBirth {
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

    /// Create a new Date of Birth.
    /// - Parameters:
    ///   - year: The year.
    ///   - month: The month.
    ///   - day: The day.
    public init(year: UInt16 = 0, month: Month = .unknown, day: UInt8 = 0) {
        self.year = year
        self.month = month
        self.day = day
    }
}


extension DateOfBirth {
    /// The date components representation for the date.
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

        return components
    }

    /// Convert to Swift Date representation.
    ///
    /// Uses the current `Calendar`.
    /// Returns `nil` if a date with matching components couldn't be found.
    public var date: Date? {
        Calendar.current.date(from: dateComponents)
    }


    /// Initialize date from date components.
    ///
    /// - Note: Date components `year`, `month` and `day` are optional. If components are not provided
    ///     the respective properties will be initialized as zeros.
    /// - Parameter components: The Swift Date Components.
    public init(from components: DateComponents) {
        let year = components.year.map(UInt16.init) ?? 0
        let month = components.month.map(UInt8.init) ?? 0
        let day = components.day.map(UInt8.init) ?? 0

        self.init(year: year, month: Month(rawValue: month), day: day)
    }

    /// Initialize date from a date and current `Calendar`.
    /// - Parameter date: The date to initialize from.
    public init(from date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        self.init(from: components)
    }
}


extension DateOfBirth: Hashable, Sendable {}


extension DateOfBirth: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let year = UInt16(from: &byteBuffer, preferredEndianness: endianness),
              let month = Month(from: &byteBuffer, preferredEndianness: endianness),
              let day = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.init(year: year, month: month, day: day)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        year.encode(to: &byteBuffer, preferredEndianness: endianness)
        month.encode(to: &byteBuffer, preferredEndianness: endianness)
        day.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
