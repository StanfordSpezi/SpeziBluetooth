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


/// The day of week.
///
/// Specifies the day within a seven-day week as specified in IOS 8601.
///
/// Refer to GATT Specification Supplement, 3.73 Day of Week.
public struct DayOfWeek {
    /// Unknown day of week.
    public static let unknown = DayOfWeek(rawValue: 0)
    /// Monday.
    public static let monday = DayOfWeek(rawValue: 1)
    /// Tuesday.
    public static let tuesday = DayOfWeek(rawValue: 2)
    /// Wednesday.
    public static let wednesday = DayOfWeek(rawValue: 3)
    /// Thursday.
    public static let thursday = DayOfWeek(rawValue: 4)
    /// Friday.
    public static let friday = DayOfWeek(rawValue: 5)
    /// Saturday.
    public static let saturday = DayOfWeek(rawValue: 6)
    /// Sunday.
    public static let sunday = DayOfWeek(rawValue: 7)


    /// The raw value.
    public let rawValue: UInt8


    /// Initialize using a raw value day of week.
    /// - Parameter rawValue: The day of week.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension DayOfWeek: RawRepresentable {}


extension DayOfWeek: Hashable, Sendable {}


extension DayOfWeek: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt8(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}
