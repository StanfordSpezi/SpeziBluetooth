//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// The operand format.
///
/// The operand defines the content of a operation in combination with the ``RecordAccessOpCode`` and the ``RecordAccessOperator``.
/// - Note: The format of the operand might differ depending on the op code and operator used.
///     Therefore, a typical implementation is done using a enum with associated values.
///
/// The format of a operand is defined by the Service specification using the ``RecordAccessControlPoint`` characteristic.
///
/// Refer to GATT Specification Supplement, 3.178.3 Operand field.
public protocol RecordAccessOperand: ByteEncodable, Sendable {
    /// General Response representation.
    ///
    /// The operand format with the code ``RecordAccessOpCode/responseCode`` contains at least the information modeled with
    /// ``RecordAccessGeneralResponse``. This property returns this information in the format of a ``RecordAccessGeneralResponse`` type
    /// if the operand is modeling the content of a response with the code ``RecordAccessOpCode/responseCode``.
    ///
    /// - Note: This property is optional to implement and returns `nil` by default.
    var generalResponse: RecordAccessGeneralResponse? { get }

    /// Decode a operand form the `ByteBuffer`.
    ///
    /// Initialize a new instance using the byte representation provided by the `ByteBuffer`.
    /// This call should move the `readerIndex` forwards.
    ///
    /// The ``RecordAccessOpCode`` and ``RecordAccessOperator`` might be relevant to decide the byte representation of the operand.
    ///
    /// - Parameters:
    ///   - byteBuffer: The ByteBuffer to read from.
    ///   - opCode: The opcode of the ``RecordAccessControlPoint`` this operand is being decoded for.
    ///   - operator: The operator of the ``RecordAccessControlPoint`` this operand is being decoded for.
    init?(
        from byteBuffer: inout ByteBuffer,
        opCode: RecordAccessOpCode,
        `operator`: RecordAccessOperator
    )
}


extension RecordAccessOperand {
    /// Default implementation returning nil.
    public var generalResponse: RecordAccessGeneralResponse? {
        nil
    }
}
