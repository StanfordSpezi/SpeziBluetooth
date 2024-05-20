//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


extension RecordAccessControlPoint {
    public static func reportStoredRecords(_ content: RecordAccessOperationContent<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportStoredRecords, operator: content.operator, operand: content.operand)
    }

    public static func deleteStoredRecords(_ content: RecordAccessOperationContent<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .deleteStoredRecords, operator: content.operator, operand: content.operand)
    }

    public static func abort() -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .abortOperation, operator: .null)
    }

    public static func reportNumberOfStoredRecords(_ content: RecordAccessOperationContent<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportNumberOfStoredRecords, operator: content.operator, operand: content.operand)
    }
}
