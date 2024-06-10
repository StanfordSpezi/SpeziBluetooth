//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// The Gender of a user.
///
/// Refer to GATT Specification Supplement, 3.103 Gender.
public struct Gender {
    /// Male.
    public static let male = Gender(rawValue: 0x00)
    /// Female.
    public static let female = Gender(rawValue: 0x01)
    /// Unspecified.
    public static let unspecified = Gender(rawValue: 0x02)


    /// The raw gender value.
    public let rawValue: UInt8


    /// Crate a new Gender instance.
    /// - Parameter rawValue: The raw value.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension Gender: RawRepresentable {}


extension Gender: Hashable, Sendable {}


extension Gender: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
