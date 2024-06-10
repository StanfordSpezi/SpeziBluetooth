//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// Semantics of a generic response.
///
/// The response code defines the semantics of a general Record Access Control Point response.
/// This information is transported as part of messages with the ``RecordAccessOpCode/responseCode`` code.
///
/// Refer to GATT Specification Supplement, 3.178.4 Response Code Values.
public struct RecordAccessResponseCode {
    /// Reserved for future use.
    public static let reserved = RecordAccessResponseCode(rawValue: 0x00)
    /// Successful operation.
    public static let success = RecordAccessResponseCode(rawValue: 0x01)
    /// The received op code is not supported.
    public static let opCodeNotSupported = RecordAccessResponseCode(rawValue: 0x02)
    /// The received operator is not valid.
    ///
    /// This response code is used if an invalid operator was received (e.g., when null was expected).
    public static let invalidOperator = RecordAccessResponseCode(rawValue: 0x03)
    /// The received operator is not supported.
    public static let operatorNotSupported = RecordAccessResponseCode(rawValue: 0x04)
    /// The received operand is invalid.
    public static let invalidOperand = RecordAccessResponseCode(rawValue: 0x05)
    /// No records found.
    ///
    /// This error indicates that no records where found for the criteria of the request
    /// (e.g., when responding to a operation with code ``RecordAccessOpCode/reportStoredRecords``.
    /// - Note: The operation ``RecordAccessOpCode/reportNumberOfStoredRecords`` returns
    ///     ``RecordAccessOpCode/numberOfStoredRecordsResponse`` with a value of zero when no records are found
    ///     and doesn't used this error code.
    public static let noRecordsFound = RecordAccessResponseCode(rawValue: 0x06)
    /// Abort was unsuccessful.
    ///
    /// The ``RecordAccessOpCode/abortOperation`` operation was unsuccessful.
    public static let abortUnsuccessful = RecordAccessResponseCode(rawValue: 0x07)
    /// Procedure cannot be completed.
    public static let procedureNotCompleted = RecordAccessResponseCode(rawValue: 0x08)
    /// The requested operand is not supported.
    public static let operandNotSupported = RecordAccessResponseCode(rawValue: 0x09)
    /// The server is busy and cannot process the requested operation.
    public static let serverBusy = RecordAccessResponseCode(rawValue: 0x0A)


    /// The raw value response code.
    public let rawValue: UInt8

    /// Initialize using a raw value response code.
    /// - Parameter rawValue: The response code.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension RecordAccessResponseCode: RawRepresentable {}


extension RecordAccessResponseCode: Hashable, Sendable {}


extension RecordAccessResponseCode: Error {}


extension RecordAccessResponseCode: ByteCodable {
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
