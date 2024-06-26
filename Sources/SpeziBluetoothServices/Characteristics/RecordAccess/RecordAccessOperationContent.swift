//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Describes the content of a operation.
///
/// Describes the content of a operation identified by a ``RecordAccessOpCode``.
/// The content describes the union of an ``RecordAccessOperator`` and an ``RecordAccessOperand``.
///
/// - Note: The content format is defined by the service and suitable static members may be available depending on your imports.
///
/// ## Topics
///
/// ### General Content
/// - ``allRecords``
/// - ``firstRecord``
/// - ``lastRecord``
public struct RecordAccessOperationContent<Operand: RecordAccessOperand> {
    let `operator`: RecordAccessOperator
    let operand: Operand?

    /// Create a new operation content.
    /// - Parameters:
    ///   - operator: The operator.
    ///   - operand: The operand.
    public init(operator: RecordAccessOperator, operand: Operand? = nil) {
        self.operator = `operator`
        self.operand = operand
    }
}


extension RecordAccessOperationContent {
    /// All records.
    ///
    /// Operation applies to all records (e.g., report all records).
    public static var allRecords: RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .allRecords)
    }

    /// The first record.
    ///
    /// Returns the first record (e.g., oldest record).
    /// No operand is used.
    public static var firstRecord: RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .firstRecord)
    }

    /// The last record.
    ///
    /// Returns the last record (e.g., most recent record).
    /// No operand is used.
    public static var lastRecord: RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .lastRecord)
    }
}
