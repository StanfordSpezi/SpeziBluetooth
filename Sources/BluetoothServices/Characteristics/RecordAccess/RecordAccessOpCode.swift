//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// The operation code.
///
/// TODO: only certain operator and operands are valid!
public struct RecordAccessOpCode: RawRepresentable {
    public static let reserved = RecordAccessOpCode(rawValue: 0x00)
    public static let reportStoredRecords = RecordAccessOpCode(rawValue: 0x01)
    public static let deleteStoredRecords = RecordAccessOpCode(rawValue: 0x02)
    public static let abortOperation = RecordAccessOpCode(rawValue: 0x03)
    public static let reportNumberOfStoredRecords = RecordAccessOpCode(rawValue: 0x04)
    public static let numberOfStoredRecordsResponse = RecordAccessOpCode(rawValue: 0x05)
    public static let responseCode = RecordAccessOpCode(rawValue: 0x06)
    public static let combinedReport = RecordAccessOpCode(rawValue: 0x07) // TODO: what are these two (+ below) used for?
    public static let combinedReportResponse = RecordAccessOpCode(rawValue: 0x08)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessOpCode: Hashable, Sendable {}


extension RecordAccessOpCode: ByteCodable {
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
