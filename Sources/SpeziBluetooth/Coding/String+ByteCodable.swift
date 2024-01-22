//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO


extension String: ByteCodable {
    /// Decodes an utf8 string from its byte representation.
    ///
    /// Decodes an utf8 string from a `ByteBuffer`.
    ///
    /// - Note: This implementation assumes that all bytes in the ByteBuffer are representing
    ///     the string.
    ///
    /// This implements decoding the `utf8s` variable-length string type of Bluetooth.
    /// This implementation does not account for fixed-length strings (e.g., utf8s{#} and utf8s{#z} representations).
    ///
    /// - Note: For reference, the variable-length types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Volume 1, Part E, 3.9.3 Variable length types.
    /// - Parameter byteBuffer: The bytebuffer to decode from.
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let string = byteBuffer.readString(length: byteBuffer.readableBytes) else {
            return nil
        }

        self = string
    }

    /// Encodes an utf8 string to its byte representation.
    ///
    /// Encodes an utf8 string into a `ByteBuffer`.
    ///
    /// This implements decoding the `utf8s` variable-length string type of Bluetooth.
    /// This implementation does not account for fixed-length strings (e.g., utf8s{#} and utf8s{#z} representations).
    ///
    /// - Note: For reference, the variable-length types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Volume 1, Part E, 3.9.3 Variable length types.
    /// - Parameter byteBuffer: The bytebuffer to decode from.
    public func encode(to byteBuffer: inout ByteBuffer) {
        byteBuffer.writeString(self)
    }
}
