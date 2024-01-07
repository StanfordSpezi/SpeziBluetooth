//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

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

