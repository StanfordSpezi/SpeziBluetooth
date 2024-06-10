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


/// Represent weekday, date and time.
///
/// Refer to GATT Specification Supplement, 3.72 Day Date Time.
@dynamicMemberLookup
public struct DayDateTime {
    /// The date and time.
    public let dateTime: DateTime
    /// The weekday.
    public let dayOfWeek: DayOfWeek


    /// Initialize a new weekday, date and time.
    /// - Parameters:
    ///   - dateTime: The ``DateTime`` information.
    ///   - dayOfWeek: The day of week if available.
    public init(dateTime: DateTime, dayOfWeek: DayOfWeek) {
        self.dateTime = dateTime
        self.dayOfWeek = dayOfWeek
    }


    /// Dynamic access for date and time.
    /// - Parameter keyPath: KeyPath to the underlying ``DateTime`` information.
    /// - Returns: Returns the time value.
    public subscript<Value>(dynamicMember keyPath: KeyPath<DateTime, Value>) -> Value {
        dateTime[keyPath: keyPath]
    }
}


extension DayDateTime {
    /// The date components representation for the date and time.
    public var dateComponents: DateComponents {
        var components = dateTime.dateComponents

        if dayOfWeek.rawValue > 0 && dayOfWeek.rawValue <= 7 {
            var weekday = dayOfWeek.rawValue + 1
            if weekday > 7 {
                weekday = 1
            }
            components.weekday = Int(weekday)
        }

        return components
    }

    /// Initialize weekday, date and time from date components.
    ///
    /// - Note: Returns `nil` if not all required date components (`hour`, `minute`, `second`) are
    ///     present. Date components `year`, `month` and `day` are optional but required to encode a date information.
    ///     Date component `weekday` is optional but required to encode day of week information.
    /// - Parameter components: The Swift Date Components.
    public init?(from components: DateComponents) {
        guard let dateTime = DateTime(from: components) else {
            return nil
        }

        var weekday = components.weekday ?? 0

        // `dayOfWeek` is 1-7 with 1 is Monday, `DateComponents/weekday` is 1-7 with 1 is Sunday.
        if weekday > 0 && weekday <= 7 {
            weekday -= 1
            if weekday == 0 {
                weekday = 7
            }
        }

        self.dateTime = dateTime
        self.dayOfWeek = DayOfWeek(rawValue: UInt8(weekday))
    }

    /// Initialize date time from a date and current `Calendar`.
    /// - Parameter date: The date to initialize from.
    public init(from date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .year, .month, .day, .weekday], from: date)

        // we know that date components are present, so force-unwrapping is fine
        self.init(from: components)! // swiftlint:disable:this force_unwrapping
    }
}


extension DayDateTime: Hashable, Sendable {}


extension DayDateTime: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let dateTime = DateTime(from: &byteBuffer),
              let dayOfWeek = DayOfWeek(from: &byteBuffer) else {
            return nil
        }

        self.init(dateTime: dateTime, dayOfWeek: dayOfWeek)
    }


    public func encode(to byteBuffer: inout ByteBuffer) {
        dateTime.encode(to: &byteBuffer)
        dayOfWeek.encode(to: &byteBuffer)
    }
}
