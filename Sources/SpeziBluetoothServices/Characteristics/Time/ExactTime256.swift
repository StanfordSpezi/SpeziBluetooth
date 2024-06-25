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


/// Exact time representing using weekday, date and time including fractions of seconds.
///
/// Refer to GATT Specification Supplement, 3.91 Exact Time 256.
@dynamicMemberLookup
public struct ExactTime256 {
    /// The weekday, date and time.
    public let dayDateTime: DayDateTime
    /// Number of 1/256 fractions of a second.
    ///
    /// Set to zero if not supported.
    public let fractions256: UInt8


    /// Fractions in second.
    public var fractions: Double {
        Double(fractions256) * (1.0 / 256.0)
    }


    /// Initialize a new exact time with 256 bit second fractions.
    /// - Parameters:
    ///   - dayDateTime: The weekday, date and time.
    ///   - fractions256: The number of 1/256 fractions of a second.
    ///     Set to zero if not supported.
    public init(dayDateTime: DayDateTime, fractions256: UInt8) {
        self.dayDateTime = dayDateTime
        self.fractions256 = fractions256
    }


    /// Dynamic access for weekday, date and time.
    /// - Parameter keyPath: The KeyPath to a ``DayDateTime`` property.
    /// - Returns: Returns the time value.
    public subscript<Value>(dynamicMember keyPath: KeyPath<DayDateTime, Value>) -> Value {
        dayDateTime[keyPath: keyPath]
    }
}


extension ExactTime256 {
    /// The factor to convert the 1/256 seconds fraction to nanoseconds.
    ///
    ///         1/256 = 0,00390625 => * 10^9 is 3906250
    private static let fractionNanosecondFactor = 3906250 // saves us from using doubles :)

    /// The date components representation for the date and time.
    public var dateComponents: DateComponents {
        var components = dayDateTime.dateComponents

        components.nanosecond = Int(fractions256) * Self.fractionNanosecondFactor

        return components
    }

    /// Convert to Swift Date representation.
    ///
    /// Uses the current `Calendar`.
    /// Returns `nil` if a date with matching components couldn't be found.
    public var date: Date? {
        Calendar.current.date(from: dateComponents)
    }


    /// Initialize weekday, date and time from date components.
    ///
    /// - Note: Returns `nil` if not all required date components (`hour`, `minute`, `second`) are
    ///     present. Date components `year`, `month` and `day` are optional but required to encode a date information.
    ///     Date component `weekday` is optional but required to encode day of week information.
    ///     Date component `nanosecond` is optional but required to encode second fractions.
    /// - Parameter components: The Swift Date Components.
    public init?(from components: DateComponents) {
        var components = components

        let fractions256: UInt8
        if var nanoseconds = components.nanosecond {
            if nanoseconds >= 256 * Self.fractionNanosecondFactor { // = 10^9
                components.second = (components.second ?? 0) + nanoseconds / 1000_000_000
                nanoseconds %= 1000_000_000
            }

            // UInt8 conversion is guaranteed to work due to the check above
            fractions256 = UInt8(nanoseconds / Self.fractionNanosecondFactor)
        } else {
            fractions256 = 0
        }

        guard let dayDateTime = DayDateTime(from: components) else {
            return nil
        }

        self.init(dayDateTime: dayDateTime, fractions256: fractions256)
    }

    /// Initialize date time from a date and current `Calendar`.
    /// - Parameter date: The date to initialize from.
    public init(from date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .year, .month, .day, .weekday, .nanosecond], from: date)

        // we know that date components are present, so force-unwrapping is fine
        self.init(from: components)! // swiftlint:disable:this force_unwrapping
    }
}


extension ExactTime256: Hashable, Sendable {}


extension ExactTime256: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let dayDateTime = DayDateTime(from: &byteBuffer),
              let fractions256 = UInt8(from: &byteBuffer) else {
            return nil
        }
        self.init(dayDateTime: dayDateTime, fractions256: fractions256)
    }


    public func encode(to byteBuffer: inout ByteBuffer) {
        dayDateTime.encode(to: &byteBuffer)
        fractions256.encode(to: &byteBuffer)
    }
}


extension ExactTime256: Codable {}
