//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


extension RecordAccessControlPoint {
    /// Report stored records operation.
    ///
    /// Reports the requested set of stored records via notify of the respective measurement characteristic.
    /// - Note: The service specification specifies valid ``RecordAccessOperator`` and the ``RecordAccessOperand`` format.
    ///
    /// After record transmission completed, the control point responds with the ``RecordAccessOpCode/responseCode`` code.
    ///
    /// - Parameter content: The content of the operation.
    /// - Returns: The Record Access Control Point value.
    public static func reportStoredRecords(_ content: RecordAccessOperationContent<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportStoredRecords, operator: content.operator, operand: content.operand)
    }

    /// Delete stored records.
    ///
    /// Delete the requested set of stored records.
    /// - Note: The service specification specifies valid ``RecordAccessOperator`` and the ``RecordAccessOperand`` format.
    ///
    /// After record transmission is completed, the control point responds with the ``RecordAccessOpCode/responseCode`` code .
    ///
    /// - Parameter content: The content of the operation.
    /// - Returns: The Record Access Control Point value.
    public static func deleteStoredRecords(_ content: RecordAccessOperationContent<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .deleteStoredRecords, operator: content.operator, operand: content.operand)
    }

    /// Abort the current operation.
    ///
    /// The operator is ``RecordAccessOperator/null`` and no operand is used.
    ///
    /// The control point responds with the ``RecordAccessOpCode/responseCode`` code.
    ///
    /// - Returns: The Record Access Control Point value.
    public static func abort() -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .abortOperation, operator: .null)
    }

    /// Report the number of stored records.
    ///
    /// Reports the number of stored records on the peripheral.
    /// - Note: The service specification specifies valid ``RecordAccessOperator`` and the ``RecordAccessOperand`` format.
    ///
    /// The number of stored records is returned using ``RecordAccessOpCode/numberOfStoredRecordsResponse``.
    /// Erroneous conditions are returned using the ``RecordAccessOpCode/responseCode`` code.
    ///
    /// - Parameter content: The content of the operation.
    /// - Returns: The Record Access Control Point value.
    public static func reportNumberOfStoredRecords(_ content: RecordAccessOperationContent<Operand>) -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportNumberOfStoredRecords, operator: content.operator, operand: content.operand)
    }
}
