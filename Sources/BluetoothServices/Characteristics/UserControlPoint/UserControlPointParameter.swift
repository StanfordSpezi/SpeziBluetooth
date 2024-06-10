//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public protocol UserControlPointParameter: ByteEncodable, Hashable, Sendable {
    var opCode: UserControlPointOpCode { get }


    init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness, opCode: UserControlPointOpCode)
}
