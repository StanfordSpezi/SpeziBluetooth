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


/// Filter types used with the generic operand.
///
/// These filter types are used with the ``RecordAccessGenericOperand``.
public struct RecordAccessFilterType {
    /// Reserved for future use.
    public static let reserved = RecordAccessFilterType(rawValue: 0x00)
    /// Filter for a record's sequence number.
    public static let sequenceNumber = RecordAccessFilterType(rawValue: 0x01)
    /// Filter for a record's user facing time.
    public static let userFacingTime = RecordAccessFilterType(rawValue: 0x02)


    /// The raw value filter type.
    public let rawValue: UInt8

    /// Initialize using a raw value filter type.
    /// - Parameter rawValue: The filter type.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessFilterType: RawRepresentable {}


extension RecordAccessFilterType: Hashable, Sendable {}


extension RecordAccessFilterType: ByteCodable {
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
