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
import SpeziBluetooth


public protocol _RecordAccessControlPoint: ControlPointCharacteristic { // TODO: naming, visibility, SPI?
    associatedtype Operand: RecordAccessOperand // TODO: docs

    var opCode: RecordAccessOpCode { get }
    var `operator`: RecordAccessOperator { get }
    var operand: Operand? { get }
}


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


extension RecordAccessControlPoint: _RecordAccessControlPoint {}


extension RecordAccessControlPoint: Equatable where Operand: Equatable {}


extension RecordAccessControlPoint: Hashable where Operand: Hashable {}


extension RecordAccessControlPoint: Sendable where Operand: Sendable {}


extension RecordAccessControlPoint: ControlPointCharacteristic {}


extension RecordAccessControlPoint: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let opCode = RecordAccessOpCode(from: &byteBuffer, preferredEndianness: endianness),
              let `operator` = RecordAccessOperator(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        // TODO: differentiate between expected nil
        // TODO: operand might be nil expectedly!
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
