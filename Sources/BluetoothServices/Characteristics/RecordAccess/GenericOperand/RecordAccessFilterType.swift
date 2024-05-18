//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore


public struct RecordAccessFilterType: RawRepresentable {
    public static let reserved = RecordAccessFilterType(rawValue: 0x00)
    public static let sequenceNumber = RecordAccessFilterType(rawValue: 0x01)
    public static let userFacingTime = RecordAccessFilterType(rawValue: 0x02) // TODO: base time + offset time?

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessFilterType: Hashable, Sendable {}


extension RecordAccessFilterType: ByteCodable {
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
