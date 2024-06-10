//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public struct UserControlPointResponseValue {
    public static let reserved = UserControlPointResponseValue(rawValue: 0x00)
    public static let success = UserControlPointResponseValue(rawValue: 0x01)
    public static let opCodeNotSupported = UserControlPointResponseValue(rawValue: 0x02)
    public static let invalidParameter = UserControlPointResponseValue(rawValue: 0x03)
    public static let operationFailed = UserControlPointResponseValue(rawValue: 0x04)
    public static let userNotAuthorized = UserControlPointResponseValue(rawValue: 0x05)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension UserControlPointResponseValue: RawRepresentable {}


extension UserControlPointResponseValue: Hashable, Sendable {}


extension UserControlPointResponseValue: ByteCodable {
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
