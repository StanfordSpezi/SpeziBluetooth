//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// The Height of a user.
///
/// Refer to GATT Specification Supplement, 3.116 Height.
public struct Height {
    /// The raw height value.
    ///
    /// The value is in units of 0.01 meter.
    public let rawValue: UInt16

    /// Create new height with raw value.
    ///
    /// - Parameter rawValue: The raw height value in units of 0.01 meter.
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}


extension Height {
    /// The height value in meter.
    public var double: Double {
        rawValue * 0.01
    }

    /// Create new height.
    /// - Parameter height: The height in meter.
    public init(_ height: Double) {
        self.init(rawValue: UInt16(height / 0.01))
    }
}


extension Height: RawRepresentable {}


extension Height: Hashable, Sendable {}


extension Height: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
