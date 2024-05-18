//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// The operator applying to the operand.
public struct RecordAccessOperator: RawRepresentable {
    public static let null = RecordAccessOperator(rawValue: 0x00)
    public static let allRecords = RecordAccessOperator(rawValue: 0x01)
    public static let lessThanOrEqualTo = RecordAccessOperator(rawValue: 0x02)
    public static let greaterThanOrEqual = RecordAccessOperator(rawValue: 0x03)
    public static let withinInclusiveRangeOf = RecordAccessOperator(rawValue: 0x04)
    public static let firstRecord = RecordAccessOperator(rawValue: 0x05)
    public static let lastRecord = RecordAccessOperator(rawValue: 0x06)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessOperator: Hashable, Sendable {}


extension RecordAccessOperator: ByteCodable {
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
