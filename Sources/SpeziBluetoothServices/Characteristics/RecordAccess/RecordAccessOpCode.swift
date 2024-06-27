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
/// The operation code defines the type of operation.
/// Further, it defines with ``RecordAccessOperator`` to used and what general information is included in the ``RecordAccessOperand`` format.
/// - Note: The applicable values are specified by the respective Service specification.
///
/// Refer to GATT Specification Supplement, 3.178.1 Op Code field.
public struct RecordAccessOpCode {
    /// Reserved for future use.
    public static let reserved = RecordAccessOpCode(rawValue: 0x00)
    /// Report stored records.
    ///
    /// Reports the requested set of stored records via notify of the respective measurement characteristic.
    /// - Note: The service specification specifies valid ``RecordAccessOperator`` and the ``RecordAccessOperand`` format.
    ///
    /// After record transmission completed, the control point responds with the ``responseCode`` code.
    public static let reportStoredRecords = RecordAccessOpCode(rawValue: 0x01)
    /// Delete stored records.
    ///
    /// Delete the requested set of stored records.
    /// - Note: The service specification specifies valid ``RecordAccessOperator`` and the ``RecordAccessOperand`` format.
    ///
    /// After record transmission is completed, the control point responds with the ``responseCode`` code .
    public static let deleteStoredRecords = RecordAccessOpCode(rawValue: 0x02)
    /// Abort the current operation.
    ///
    /// The operator is ``RecordAccessOperator/null`` and no operand is used.
    ///
    /// The control point responds with the ``responseCode`` code.
    public static let abortOperation = RecordAccessOpCode(rawValue: 0x03)
    /// Report the number of stored records.
    ///
    /// Reports the number of stored records on the peripheral.
    /// - Note: The service specification specifies valid ``RecordAccessOperator`` and the ``RecordAccessOperand`` format.
    ///
    /// The number of stored records is returned using ``numberOfStoredRecordsResponse``.
    /// Erroneous conditions are returned using the ``responseCode`` code.
    public static let reportNumberOfStoredRecords = RecordAccessOpCode(rawValue: 0x04)
    /// Response returning the number of stored records.
    ///
    /// This is the response code to ``reportNumberOfStoredRecords``.
    /// The operator is ``RecordAccessOperator/null``.
    /// The operand contains the number of stored records.
    /// - Note: The exact field size is specified by the Service.
    public static let numberOfStoredRecordsResponse = RecordAccessOpCode(rawValue: 0x05)
    /// Returns a general response.
    ///
    /// The operator is ``RecordAccessOperator/null``.
    /// The operand should include information similar to ``RecordAccessGeneralResponse`` (specifically containing an error code
    /// of ``RecordAccessResponseCode``).
    public static let responseCode = RecordAccessOpCode(rawValue: 0x06)
    /// Request a combined report.
    ///
    /// After record transmission, the control point responds with the ``responseCode`` code.
    /// - Note: The service specification specifies valid ``RecordAccessOperator`` and the ``RecordAccessOperand`` format.
    public static let combinedReport = RecordAccessOpCode(rawValue: 0x07)
    /// Response of a combined report.
    ///
    /// The operator is ``RecordAccessOperator/null``.
    /// The operand contains the number of records.
    /// - Note: The exact field size is specified by the Service.
    public static let combinedReportResponse = RecordAccessOpCode(rawValue: 0x08)

    /// The raw value op code.
    public let rawValue: UInt8


    /// Initialize using a raw value op code.
    /// - Parameter rawValue: The op code.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessOpCode: RawRepresentable {}


extension RecordAccessOpCode: Hashable, Sendable {}


extension RecordAccessOpCode: ByteCodable {
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
