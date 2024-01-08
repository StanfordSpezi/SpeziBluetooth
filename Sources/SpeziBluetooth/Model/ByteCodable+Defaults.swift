//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import NIO


extension String: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        // TODO: how to do the length thingy?
        guard let string = byteBuffer.readString(length: byteBuffer.readableBytes) else {
            return nil
        }

        self = string
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        byteBuffer.writeString(self)
    }
}


extension Data: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            return nil
        }
        self = data
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        byteBuffer.writeData(self)
    }
}


extension ByteBuffer: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        self = byteBuffer
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        var this = self
        byteBuffer.writeBuffer(&this)
    }
}
