//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO


extension Bool: ByteCodable {
    /// Decode a `Bool` from a Boolean characteristic (see GATT Specification Supplement, 3.36 Boolean).
    ///
    /// Be aware of the difference to Boolean fields (see GATT Specification Supplement, 3.36.1 Boolean).
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let bytes = byteBuffer.readBytes(length: 1),
              let byte = bytes.first else {
            return nil
        }

        self = byte == 1
    }

    /// Encodes a `Bool` to a Boolean characteristic (see GATT Specification Supplement, 3.36 Boolean).
    ///
    /// Be aware of the difference to Boolean fields (see GATT Specification Supplement, 3.36.1 Boolean).
    public func encode(to byteBuffer: inout ByteBuffer) {
        byteBuffer.writeBytes([self ? 1 : 0])
    }
}
