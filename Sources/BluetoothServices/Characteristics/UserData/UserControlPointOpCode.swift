//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public struct UserControlPointOpCode {
    public static let reserved = UserControlPointOpCode(rawValue: 0x00)
    public static let registerNewUser = UserControlPointOpCode(rawValue: 0x01)
    public static let consent = UserControlPointOpCode(rawValue: 0x02)
    public static let deleteUserData = UserControlPointOpCode(rawValue: 0x03)
    public static let listAllUsers = UserControlPointOpCode(rawValue: 0x04) // TODO: optional
    public static let deleteUser = UserControlPointOpCode(rawValue: 0x05) // TODO: optional
    public static let response = UserControlPointOpCode(rawValue: 0x20)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension UserControlPointOpCode: RawRepresentable {}


extension UserControlPointOpCode: Hashable, Sendable {}


extension UserControlPointOpCode: ByteCodable {
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
