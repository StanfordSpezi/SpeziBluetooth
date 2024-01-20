//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO


/// `ByteCodable` types that are a `FixedWithInteger`.
///
/// - Note: For reference, the basic types in Bluetooth are illustrated in
///     Bluetooth Core Specification, Part E, 3.9.1 Basic types.
protocol FixedWidthByteCodable: FixedWidthInteger, ByteCodable {}


extension FixedWidthByteCodable {
    /// Decodes a fixed-width integer from its byte representation.
    ///
    /// Decodes a `FixedWidthInteger` from a `ByteBuffer`.
    ///
    /// This covers `uint8`, `uint16`, `uint32` and `uint64` of `uint#` types of Bluetooth.
    /// Further, it covers `int8`, `int16`, `int32`, and `int64` of `int#` types of Bluetooth.
    ///
    /// - Note: For reference, the basic types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Part E, 3.9.1 Basic types.
    /// - Parameter byteBuffer: The bytebuffer to decode from.
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let value = byteBuffer.readInteger(endianness: .little, as: Self.self) else {
            return nil
        }
        self = value
    }

    /// Encodes a fixed-width integer to its byte representation.
    ///
    /// Encodes a `FixedWidthInteger` into a `ByteBuffer`.
    ///
    /// This covers `uint8`, `uint16`, `uint32` and `uint64` of `uint#` types of Bluetooth.
    /// Further, it covers `int8`, `int16`, `int32`, and `int64` of `int#` types of Bluetooth.
    ///
    /// - Note: For reference, the basic types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Part E, 3.9.1 Basic types.
    /// - Parameter byteBuffer: The bytebuffer to decode from.
    public func encode(to byteBuffer: inout ByteBuffer) {
        byteBuffer.writeInteger(self, endianness: .little)
    }
}


extension UInt8: FixedWidthByteCodable {}
extension UInt16: FixedWidthByteCodable {}
extension UInt32: FixedWidthByteCodable {}
extension UInt64: FixedWidthByteCodable {}


extension Int8: FixedWidthByteCodable {}
extension Int16: FixedWidthByteCodable {}
extension Int32: FixedWidthByteCodable {}
extension Int64: FixedWidthByteCodable {}
