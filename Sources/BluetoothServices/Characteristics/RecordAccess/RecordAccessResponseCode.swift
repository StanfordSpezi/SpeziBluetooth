//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


// TODO: Docs, how to use that?
public struct RecordAccessResponseCode: RawRepresentable {
    public static let reserved = RecordAccessResponseCode(rawValue: 0x00)
    public static let success = RecordAccessResponseCode(rawValue: 0x01)
    public static let opCodeNotSupported = RecordAccessResponseCode(rawValue: 0x02)
    public static let invalidOperator = RecordAccessResponseCode(rawValue: 0x03)
    public static let operatorNotSupported = RecordAccessResponseCode(rawValue: 0x04)
    public static let invalidOperand = RecordAccessResponseCode(rawValue: 0x05)
    public static let noRecordsFound = RecordAccessResponseCode(rawValue: 0x06)
    public static let abortUnsuccessful = RecordAccessResponseCode(rawValue: 0x07)
    public static let procedureNotCompleted = RecordAccessResponseCode(rawValue: 0x08)
    public static let operandNotSupported = RecordAccessResponseCode(rawValue: 0x09)
    public static let serverBusy = RecordAccessResponseCode(rawValue: 0x0A)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessResponseCode: Hashable, Sendable {}


extension RecordAccessResponseCode: Error {}


extension RecordAccessResponseCode: ByteCodable {
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
