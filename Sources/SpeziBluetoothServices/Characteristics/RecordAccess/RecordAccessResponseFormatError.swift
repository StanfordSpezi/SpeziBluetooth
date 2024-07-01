//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Error when receiving the response of a Record Access Control Point value.
///
/// The value returned from the Record Access Control Point characteristic for a previously sent
/// request has unexpected format.
public struct RecordAccessResponseFormatError {
    /// The reason for the format error.
    public enum Reason {
        /// The response had an unexpected opcode.
        case unexpectedOpcode
        /// The response had an unexpected operator.
        case unexpectedOperator
        /// The operand had an unexpected format.
        case unexpectedOperand
        /// The response indicated that it is the response to a different request opcode than anticipated.
        case invalidResponse
    }

    /// The opcode of the response received.
    public let responseCode: RecordAccessOpCode
    /// The operator of the response received.
    public let responseOperator: RecordAccessOperator
    /// The operand of the response received.
    public let responseOperand: (any RecordAccessOperand)?
    /// The reason of the error.
    public let reason: Reason


    /// Initialize a new error.
    /// - Parameters:
    ///   - response: The response for which this error occurred.
    ///   - reason: The reason for the error.
    public init<Response: _RecordAccessControlPoint>(response: Response, reason: Reason) {
        self.responseCode = response.opCode
        self.responseOperator = response.operator
        self.responseOperand = response.operand
        self.reason = reason
    }
}


extension RecordAccessResponseFormatError.Reason: Sendable {}


extension RecordAccessResponseFormatError: Error {}
