//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import NIO


extension Data: ByteCodable {
    /// Decode a data blob.
    ///
    /// Copies all bytes from the ByteBuffer into a `Data` instance.
    /// - Parameter byteBuffer: The ByteBuffer to decode from.
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            return nil
        }
        self = data
    }

    /// Encode a data blob.
    ///
    /// Copies the data instance into the ByteBuffer.
    /// - Parameter byteBuffer: The ByteBuffer to write to.
    public func encode(to byteBuffer: inout ByteBuffer) {
        byteBuffer.writeData(self)
    }
}
