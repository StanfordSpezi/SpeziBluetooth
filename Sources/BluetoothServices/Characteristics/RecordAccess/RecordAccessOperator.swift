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
///
/// The operator applies semantics to the ``RecordAccessOperand``.
/// - Note: The applicable values are specified by the respective Service specification.
///
/// Refer to GATT Specification Supplement, 3.178.2 Operator field.
public struct RecordAccessOperator {
    /// Null operator.
    public static let null = RecordAccessOperator(rawValue: 0x00)
    /// All records.
    ///
    /// Operation applies to all records (e.g., report all records).
    public static let allRecords = RecordAccessOperator(rawValue: 0x01)
    /// Less than or equal to a maximum value.
    ///
    /// The maximum value is specified within the ``RecordAccessOperand`` format.
    /// - Note: The Operand might specify additional filtering semantics.
    public static let lessThanOrEqualTo = RecordAccessOperator(rawValue: 0x02)
    /// Greater than or equal to a minimum value.
    ///
    /// The minimum value is specified within the ``RecordAccessOperand`` format.
    /// - Note: The Operand might specify additional filtering semantics.
    public static let greaterThanOrEqual = RecordAccessOperator(rawValue: 0x03)
    /// Within a closed range of a value pair.
    ///
    /// The minimum and maximum values are specified within the ``RecordAccessOperand`` format.
    /// - Note: The Operand might specify additional filtering semantics.
    public static let withinInclusiveRangeOf = RecordAccessOperator(rawValue: 0x04)
    /// The first record.
    ///
    /// Returns the first record (e.g., oldest record).
    /// No operand is used.
    public static let firstRecord = RecordAccessOperator(rawValue: 0x05)
    /// The last record.
    ///
    /// Returns the last record (e.g., most recent record).
    /// No operand is used.
    public static let lastRecord = RecordAccessOperator(rawValue: 0x06)


    /// The raw value operator.
    public let rawValue: UInt8


    /// Initialize using a raw value operator.
    /// - Parameter rawValue: The operator.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessOperator: RawRepresentable {}


extension RecordAccessOperator: Hashable, Sendable {}


extension RecordAccessOperator: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt8(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}
