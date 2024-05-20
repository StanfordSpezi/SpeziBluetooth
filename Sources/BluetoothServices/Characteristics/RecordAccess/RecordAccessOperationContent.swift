//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


public struct RecordAccessOperationContent<Operand: RecordAccessOperand> { // TODO: I don't like the naming!
    let `operator`: RecordAccessOperator
    let operand: Operand?

    init(operator: RecordAccessOperator, operand: Operand? = nil) {
        self.operator = `operator`
        self.operand = operand
    }
}


extension RecordAccessOperationContent {
    public static var allRecords: RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .allRecords)
    }

    public static var firstRecord: RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .firstRecord)
    }

    public static var lastRecord: RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .lastRecord)
    }
}
