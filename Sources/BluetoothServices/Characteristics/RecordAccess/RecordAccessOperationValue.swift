//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


public struct RecordAccessOperationValue<Operand: RecordAccessOperand> { // TODO: naming?
    let `operator`: RecordAccessOperator
    let operand: Operand?

    init(operator: RecordAccessOperator, operand: Operand? = nil) {
        self.operator = `operator`
        self.operand = operand
    }
}


extension RecordAccessOperationValue {
    public static var allRecords: RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .allRecords)
    }

    public static var firstRecord: RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .firstRecord)
    }

    public static var lastRecord: RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .lastRecord)
    }
}
