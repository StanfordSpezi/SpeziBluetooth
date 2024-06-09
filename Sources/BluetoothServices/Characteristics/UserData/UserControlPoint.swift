//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore
import SpeziBluetooth


public struct UserControlPoint {
    public struct OpCode {
        public static let reserved = OpCode(rawValue: 0x00)
        public static let registerNewUser = OpCode(rawValue: 0x01)
        public static let consent = OpCode(rawValue: 0x02)
        public static let deleteUserData = OpCode(rawValue: 0x03)
        public static let listAllUsers = OpCode(rawValue: 0x04) // TODO: optional
        public static let deleteUser = OpCode(rawValue: 0x05) // TODO: optional
        public static let responseCode = OpCode(rawValue: 0x20)

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }


    public let opcode: OpCode
    public let parameter: Any // TODO: what?
}


extension UserControlPoint.OpCode: RawRepresentable {}


extension UserControlPoint.OpCode: Hashable, Sendable {}


extension UserControlPoint.OpCode: ByteCodable {
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


extension UserControlPoint: ControlPointCharacteristic {}
