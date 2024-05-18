//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public enum RecordAccessGenericOperand: RecordAccessOperand { // TODO: we need a custom one for Omron!
    case generalResponse(RecordAccessGeneralResponse)
    case filterCriteria(RecordAccessFilterCriteria)
    case numberOfRecords(UInt16)
    // TODO: case sequenceNumber(UInt16) // TODO: this is specific to Omron devices?


    public init?(
        from byteBuffer: inout ByteBuffer,
        preferredEndianness endianness: Endianness,
        opCode: RecordAccessOpCode,
        operator: RecordAccessOperator
    ) {
        switch opCode {
        case .numberOfStoredRecordsResponse:
            guard let count = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .numberOfRecords(count)
        case .responseCode:
            guard let response = RecordAccessGeneralResponse(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .generalResponse(response)
        case .reportStoredRecords, .deleteStoredRecords, .reportNumberOfStoredRecords:
            guard let filterCriteria = RecordAccessFilterCriteria(
                from: &byteBuffer,
                preferredEndianness: endianness,
                operator: `operator`
            ) else {
                return nil
            }

            self = .filterCriteria(filterCriteria)
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        switch self {
        case let .generalResponse(response):
            response.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .filterCriteria(criteria):
            criteria.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .numberOfRecords(value):
            value.encode(to: &byteBuffer, preferredEndianness: endianness)
        }
    }
}


extension RecordAccessOperationValue where Operand == RecordAccessGenericOperand {
    public static func lessThanOrEqualTo<Value>(_ filterCriteria: RecordAccessFilterCriteriaScalar<Value>) -> RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .lessThanOrEqualTo, operand: .filterCriteria(RecordAccessFilterCriteria(filterCriteria)))
    }

    public static func greaterThanOrEqualTo<Value>(_ filterCriteria: RecordAccessFilterCriteriaScalar<Value>) -> RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .greaterThanOrEqual, operand: .filterCriteria(RecordAccessFilterCriteria(filterCriteria)))
    }

    public static func withinInclusiveRangeOf<Value>(_ filterCriteria: RecordAccessFilterCriteriaTuple<Value>) -> RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .withinInclusiveRangeOf, operand: .filterCriteria(RecordAccessFilterCriteria(filterCriteria)))
    }
}
