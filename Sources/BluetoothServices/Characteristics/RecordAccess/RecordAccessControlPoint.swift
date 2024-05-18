//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore


public struct RecordAccessControlPoint<Operand: RecordAccessOperand> {
    public let opCode: RecordAccessOpCode
    public let `operator`: RecordAccessOperator
    public let operand: Operand?

    // TODO: enum-like struct initializers for opcodes!

    public init(opCode: RecordAccessOpCode, operator: RecordAccessOperator, operand: Operand? = nil) { // TODO: private?
        self.opCode = opCode
        self.operator = `operator`
        self.operand = operand
    }
}


extension RecordAccessControlPoint: Equatable where Operand: Equatable {}


extension RecordAccessControlPoint: Hashable where Operand: Hashable {}


extension RecordAccessControlPoint: Sendable where Operand: Sendable {}


extension RecordAccessControlPoint: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let opCode = RecordAccessOpCode(from: &byteBuffer, preferredEndianness: endianness),
              let `operator` = RecordAccessOperator(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        guard let operand = Operand(from: &byteBuffer, preferredEndianness: endianness, opCode: opCode, operator: `operator`) else {
            return nil
        }

        self.init(opCode: opCode, operator: `operator`, operand: operand)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        opCode.encode(to: &byteBuffer, preferredEndianness: endianness)
        `operator`.encode(to: &byteBuffer, preferredEndianness: endianness)

        operand?.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
