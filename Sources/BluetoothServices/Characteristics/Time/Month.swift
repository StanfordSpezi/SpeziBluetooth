//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// The month.
public struct Month {
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

    /// The raw value month.
    public let rawValue: UInt8


    /// Initialize using a raw value month.
    /// - Parameter rawValue: The month.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension Month: RawRepresentable {}


extension Month: Hashable, Sendable {}


extension Month: ByteCodable {
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
