//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


public enum RecordAccessResponseFormatError {
    /// Received an unexpected response.
    ///
    /// An unexpected response is a response where either the opcode, the operator code or the operand format is
    /// unexpected for the matching request.
    case unexpectedResponse(RecordAccessOpCode, RecordAccessOperator)
}


extension RecordAccessResponseFormatError: Error {}
