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


/// Protocol for the Record Access Control Point characteristic.
public protocol _RecordAccessControlPoint: ControlPointCharacteristic { // swiftlint:disable:this type_name
    /// The operand format.
    associatedtype Operand: RecordAccessOperand

    /// The operation code.
    var opCode: RecordAccessOpCode { get }
    /// The operator.
    var `operator`: RecordAccessOperator { get }
    /// The operand.
    var operand: Operand? { get }
}


/// Service-specific operations to manage a set of data records.
///
/// The Record Access Control Point characteristic implements request and response operations to manage a set of data records
/// (e.g., blood pressure measurements).
/// - Note: The exact format is specified by the Service.
///
/// Refer to GATT Specification Supplement, 3.178 Record Access Control Point.
///
/// ## Topics
///
/// ### Operations
/// - ``reportStoredRecords(_:)``
/// - ``deleteStoredRecords(_:)``
/// - ``abort()``
/// - ``reportNumberOfStoredRecords(_:)``
public struct RecordAccessControlPoint<Operand: RecordAccessOperand> {
    /// The operation code.
    public let opCode: RecordAccessOpCode
    /// The operator.
    public let `operator`: RecordAccessOperator
    /// The operand.
    public let operand: Operand?


    /// Initialize a new operation.
    /// - Parameters:
    ///   - opCode: The opcode.
    ///   - operator: The operator.
    ///   - operand: The operand.
    public init(opCode: RecordAccessOpCode, `operator`: RecordAccessOperator, operand: Operand? = nil) {
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


        // If an operand is required is dependent on the op code and operator.
        // This might be implementation specific (e.g., custom op codes). Therefore, we can't enforce anything here.
        // The receiver would need to unwrap the optional anyways.
        let operand = Operand(from: &byteBuffer, preferredEndianness: endianness, opCode: opCode, operator: `operator`)

        self.init(opCode: opCode, operator: `operator`, operand: operand)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        opCode.encode(to: &byteBuffer, preferredEndianness: endianness)
        `operator`.encode(to: &byteBuffer, preferredEndianness: endianness)

        operand?.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
