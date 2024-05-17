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

/*
 typedef NS_ENUM(UInt8, RACPOpCode) {
    RACPOpCodeReserved = 0x00,
    RACPOpCodeReportStoredRecords = 0x01,
    RACPOpCodeDeleteStoredRecords = 0x02,
    RACPOpCodeReportNumberOfStoredRecords = 0x04,
    RACPOpCodeNumberOfStoredRecordsResponse = 0x05,
    RACPOpCodeResponseCode = 0x06,
    RACPOpCodeReportSequenceNumberOfLatestRecord = 0x10,
    RACPOpCodeSequenceNumberOfLatestRecordResponse = 0x11,
};

 typedef NS_ENUM(UInt8, RACPOperator) {
    RACPOperatorNull = 0x00,
    RACPOperatorAllRecords = 0x01,
    RACPOperatorGreaterThanOrEqualTo = 0x03,
};

 typedef NS_ENUM(UInt8, RACPFilterType) {
    RACPFilterTypeReserved = 0x00,
    RACPFilterTypeSequenceNumber = 0x01,
    RACPFilterTypeUserFacingTime = 0x02,
};

typedef NS_ENUM(UInt8, RACPResponseValue) {
    RACPResponseValueReserved = 0x00,
    RACPResponseValueSuccess = 0x01,
    RACPResponseValueOpCodeNotSupported = 0x02,
    RACPResponseValueInvalidOperator = 0x03,
    RACPResponseValueOperatorNotSupported = 0x04,
    RACPResponseValueInvalidOperand = 0x05,
    RACPResponseValueNoRecordsFound = 0x06,
    RACPResponseValueAbortUnsuccessful = 0x07,
    RACPResponseValueProcedureNotCompleted = 0x08,
    RACPResponseValueOperandNotSupported = 0x09,
};

 typedef struct {
    RACPOpCode opCode;
    RACPOperator operator;
    union {
        struct { RACPFilterType filterType; UInt16 value; } filterCriteria;
        struct { RACPOpCode requestOpCode; RACPResponseValue value; } generalResponse;
        UInt16 numberOfRecords;
        UInt16 sequenceNumber;
    } operand;
} RACPCommand;
 */

public enum GenericOperand {
    public struct FilterType: RawRepresentable {
        public static let reserved = FilterType(rawValue: 0x00)
        public static let sequenceNumber = FilterType(rawValue: 0x01)
        public static let userFacingTime = FilterType(rawValue: 0x02)

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    public struct FilterCriteria {
        public let filterType: FilterType
        public let value: UInt16
    }

    public struct GeneralResponse {
        // TODO: nest type with generics is shitty!
        public let requestOpCode: RecordAccessControlPoint<GenericOperand>.OpCode
        public let response: RecordAccessControlPoint<GenericOperand>.ResponseCode
    }

    // TODO: how to do codability?
    case numberOfRecords(_ records: UInt16)
    case sequenceNumber(_ sequenceNumber: UInt16)
    case filterCriteria(_ criteria: FilterCriteria)
    case generalResponse(_ response: GeneralResponse)
}


public struct RecordAccessControlPoint<Operand: ByteCodable & Hashable & Sendable> {
    /// The operation code.
    ///
    /// TODO: only certain oeprator and operands are valid!
    public struct OpCode: RawRepresentable {
        public static let reserved = OpCode(rawValue: 0x00)
        public static let reportStoredRecords = OpCode(rawValue: 0x01)
        public static let deleteStoredRecords = OpCode(rawValue: 0x02)
        public static let abortOperation = OpCode(rawValue: 0x03)
        public static let reportNumberOfStoredRecords = OpCode(rawValue: 0x04)
        public static let numberOfStoredRecordsResponse = OpCode(rawValue: 0x05)
        public static let responseCode = OpCode(rawValue: 0x06)
        public static let combinedReport = OpCode(rawValue: 0x07)
        public static let combinedReportResponse = OpCode(rawValue: 0x00)

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// The operator applying to the operand.
    public struct Operator: RawRepresentable {
        public static let null = Operator(rawValue: 0x00)
        public static let allRecords = Operator(rawValue: 0x01)
        public static let lessThanOrEqualTo = Operator(rawValue: 0x02)
        public static let greaterThanOrEqual = Operator(rawValue: 0x03)
        public static let withinInclusiveRangeOf = Operator(rawValue: 0x04)
        public static let firstRecord = Operator(rawValue: 0x05)
        public static let lastRecord = Operator(rawValue: 0x06)

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }


    // TODO: Docs, how to use that?
    public struct ResponseCode: RawRepresentable {
        public static let reserved = ResponseCode(rawValue: 0x00)
        public static let success = ResponseCode(rawValue: 0x01)
        public static let opCodeNotSupported = ResponseCode(rawValue: 0x02)
        public static let invalidOperator = ResponseCode(rawValue: 0x03)
        public static let operatorNotSupported = ResponseCode(rawValue: 0x04)
        public static let invalidOperand = ResponseCode(rawValue: 0x05)
        public static let noRecordsFound = ResponseCode(rawValue: 0x06)
        public static let abortUnsuccessful = ResponseCode(rawValue: 0x07)
        public static let procedureNotCompleted = ResponseCode(rawValue: 0x08)
        public static let operandNotSupported = ResponseCode(rawValue: 0x09)
        public static let serverBusy = ResponseCode(rawValue: 0x0A)

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }


    public let opCode: OpCode
    public let `operator`: Operator
    public let operand: Operand

    // TODO: enum-like struct initializers for opcodes!

    public init(opCode: OpCode, operator: Operator, operand: Operand) { // TODO: private?
        self.opCode = opCode
        self.operator = `operator`
        self.operand = operand
    }
}


extension RecordAccessControlPoint.OpCode: Hashable, Sendable {}


extension RecordAccessControlPoint.Operator: Hashable, Sendable {}


extension RecordAccessControlPoint: Hashable, Sendable {} // TODO: conditionally to the Operator?


extension RecordAccessControlPoint.OpCode: ByteCodable {
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


extension RecordAccessControlPoint.Operator: ByteCodable {
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
        guard let opCode = OpCode(from: &byteBuffer, preferredEndianness: endianness),
              let `operator` = Operator(from: &byteBuffer, preferredEndianness: endianness),
              let operand = Operand(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.init(opCode: opCode, operator: `operator`, operand: operand)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        opCode.encode(to: &byteBuffer, preferredEndianness: endianness)
        `operator`.encode(to: &byteBuffer, preferredEndianness: endianness)
        operand.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
