//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


extension RecordAccessControlPoint {
    public static func reportStoredRecords(_ operation: RecordAccessOperationValue<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportStoredRecords, operator: operation.operator, operand: operation.operand)
    }

    public static func deleteStoredRecords(_ operation: RecordAccessOperationValue<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .deleteStoredRecords, operator: operation.operator, operand: operation.operand)
    }

    public static func abort() -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .abortOperation, operator: .null)
    }

    public static func reportNumberOfStoredRecords(_ operation: RecordAccessOperationValue<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportNumberOfStoredRecords, operator: operation.operator, operand: operation.operand)
    }
}


extension RecordAccessControlPoint {
    // TODO: this is specific to Ormon!!
    public static func reportSequenceNumberOfLatestRecords() -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportSequenceNumberOfLatestRecords, operator: .null)
    }
}
