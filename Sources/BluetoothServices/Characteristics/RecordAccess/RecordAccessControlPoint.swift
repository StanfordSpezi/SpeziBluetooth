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


public struct RecordAccessFilterType: RawRepresentable {
    public static let reserved = RecordAccessFilterType(rawValue: 0x00)
    public static let sequenceNumber = RecordAccessFilterType(rawValue: 0x01)
    public static let userFacingTime = RecordAccessFilterType(rawValue: 0x02) // TODO: base time + offset time?

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public struct RecordAccessFilterCriteria {
    public let filterType: RecordAccessFilterType
    public let value: UInt16
}

public struct RecordAccessGeneralResponse {
    public let requestOpCode: RecordAccessOpCode
    public let response: RecordAccessResponseCode
}


public enum GenericOperand: RecordAccessOperand { // TODO: we need a custom one for Omron!
    case generalResponse(RecordAccessGeneralResponse)
    case filterCriteria(RecordAccessFilterCriteria)
    case numberOfRecords(UInt16)
    case sequenceNumber(UInt16) // TODO: this is specific to Omron devices?


    public init?(
        from byteBuffer: inout ByteBuffer,
        preferredEndianness endianness: Endianness,
        opCode: RecordAccessOpCode,
        operator: RecordAccessOperator
    ) {
        // TODO: implement
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        // TODO: implement
    }
}


public enum RecordAccessOperation { // TODO: name: this is the combination of Operator and Operand!
    case allRecords
    case lessThanOrEqualTo(_ filterType: GenericOperand.FilterType, _ value: UInt16)
    case greaterThanOrEqualTo(_ filterType: GenericOperand.FilterType, _ value: UInt16)
    // TODO: how to implement withinRange(inclusive)?
    case firstRecord
    case lastRecord
}

extension RecordAccessControlPoint where Operand == GenericOperand {
    public static func reportStoredRecords(_ operation: RecordAccessOperation) -> RecordAccessControlPoint {
        // TODO: implement
    }

    public static func deleteStoredRecords(_ operation: RecordAccessOperation) -> RecordAccessControlPoint {

    }

    public static func abort() -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .abortOperation, operator: .null)
    }

    public static func reportNumberOfStoredRecords(_ operation: RecordAccessOperation) -> RecordAccessControlPoint {

    }

    public static func reportSequenceNumberOfLatestRecords() -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .reportSequenceNumberOfLatestRecords, operator: .null)
    }
}


/// The operation code.
///
/// TODO: only certain operator and operands are valid!
public struct RecordAccessOpCode: RawRepresentable {
    public static let reserved = RecordAccessOpCode(rawValue: 0x00)
    public static let reportStoredRecords = RecordAccessOpCode(rawValue: 0x01)
    public static let deleteStoredRecords = RecordAccessOpCode(rawValue: 0x02)
    public static let abortOperation = RecordAccessOpCode(rawValue: 0x03)
    public static let reportNumberOfStoredRecords = RecordAccessOpCode(rawValue: 0x04)
    public static let numberOfStoredRecordsResponse = RecordAccessOpCode(rawValue: 0x05)
    public static let responseCode = RecordAccessOpCode(rawValue: 0x06)
    public static let combinedReport = RecordAccessOpCode(rawValue: 0x07) // TODO: what are these two (+ below) used for?
    public static let combinedReportResponse = RecordAccessOpCode(rawValue: 0x08)

    // TODO: move that to a simple extension!
    public static let reportSequenceNumberOfLatestRecords = RecordAccessOpCode(rawValue: 0x10)
    public static let sequenceNumberOfLatestRecordsResponse = RecordAccessOpCode(rawValue: 0x11)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

/// The operator applying to the operand.
public struct RecordAccessOperator: RawRepresentable {
    public static let null = RecordAccessOperator(rawValue: 0x00)
    public static let allRecords = RecordAccessOperator(rawValue: 0x01)
    public static let lessThanOrEqualTo = RecordAccessOperator(rawValue: 0x02)
    public static let greaterThanOrEqual = RecordAccessOperator(rawValue: 0x03)
    public static let withinInclusiveRangeOf = RecordAccessOperator(rawValue: 0x04)
    public static let firstRecord = RecordAccessOperator(rawValue: 0x05)
    public static let lastRecord = RecordAccessOperator(rawValue: 0x06)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


// TODO: Docs, how to use that?
public struct RecordAccessResponseCode: RawRepresentable {
    public static let reserved = RecordAccessResponseCode(rawValue: 0x00)
    public static let success = RecordAccessResponseCode(rawValue: 0x01)
    public static let opCodeNotSupported = RecordAccessResponseCode(rawValue: 0x02)
    public static let invalidOperator = RecordAccessResponseCode(rawValue: 0x03)
    public static let operatorNotSupported = RecordAccessResponseCode(rawValue: 0x04)
    public static let invalidOperand = RecordAccessResponseCode(rawValue: 0x05)
    public static let noRecordsFound = RecordAccessResponseCode(rawValue: 0x06)
    public static let abortUnsuccessful = RecordAccessResponseCode(rawValue: 0x07)
    public static let procedureNotCompleted = RecordAccessResponseCode(rawValue: 0x08)
    public static let operandNotSupported = RecordAccessResponseCode(rawValue: 0x09)
    public static let serverBusy = RecordAccessResponseCode(rawValue: 0x0A)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


public protocol RecordAccessOperand: ByteEncodable {
    init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness, opCode: RecordAccessOpCode, operator: RecordAccessOperator)
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


extension RecordAccessOpCode: Hashable, Sendable {}


extension RecordAccessOperator: Hashable, Sendable {}


extension RecordAccessControlPoint: Equatable where Operand: Equatable {}


extension RecordAccessControlPoint: Hashable where Operand: Hashable {}


extension RecordAccessControlPoint: Sendable where Operand: Sendable {}


extension RecordAccessOpCode: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension RecordAccessOperator: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


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
