//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Error in the format of the response of a Record Access Control Point value.
///
/// The value returned from the Record Access Control Point characteristic for a previously sent
/// request has unexpected format.
public enum RecordAccessResponseFormatError {
    /// Received an unexpected response.
    ///
    /// An unexpected response is a response where either the opcode, the operator code or the operand format is
    /// unexpected for the matching request.
    case unexpectedResponse(RecordAccessOpCode, RecordAccessOperator)
}


extension RecordAccessResponseFormatError: Error {}
