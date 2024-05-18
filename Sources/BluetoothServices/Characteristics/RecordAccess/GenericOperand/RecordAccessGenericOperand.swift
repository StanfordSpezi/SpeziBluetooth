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
    case rangeFilterCriteria(RecordAccessRangeFilterCriteria)
    case numberOfRecords(UInt16)
    // TODO: case sequenceNumber(UInt16) // TODO: this is specific to Omron devices?


    public init?(
        from byteBuffer: inout ByteBuffer,
        preferredEndianness endianness: Endianness,
        opCode: RecordAccessOpCode,
        operator: RecordAccessOperator
    ) {
        switch opCode {
        case .responseCode:
            guard let response = RecordAccessGeneralResponse(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .generalResponse(response)
        case .reportStoredRecords, .deleteStoredRecords, .reportNumberOfStoredRecords:
            switch `operator` {
            case .lessThanOrEqualTo, .greaterThanOrEqual:
                guard let filterCriteria = RecordAccessFilterCriteria(from: &byteBuffer, preferredEndianness: endianness) else {
                    return nil
                }
                self = .filterCriteria(filterCriteria)
            case .withinInclusiveRangeOf:
                guard let filterCriteria = RecordAccessRangeFilterCriteria(from: &byteBuffer, preferredEndianness: endianness) else {
                    return nil
                }
                self = .rangeFilterCriteria(filterCriteria)
            default:
                return nil
            }
        case .numberOfStoredRecordsResponse:
            guard let count = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .numberOfRecords(count)
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
        case let .rangeFilterCriteria(criteria):
            criteria.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .numberOfRecords(value):
            value.encode(to: &byteBuffer, preferredEndianness: endianness)
        }
    }
}


extension RecordAccessOperationValue where Operand == RecordAccessGenericOperand {
    public static func lessThanOrEqualTo(_ filterCriteria: RecordAccessFilterCriteria) -> RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .lessThanOrEqualTo, operand: .filterCriteria(filterCriteria))
    }

    public static func greaterThanOrEqualToRecordAccessFilterCriteriaNew(_ filterCriteria: RecordAccessFilterCriteria) -> RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .greaterThanOrEqual, operand: .filterCriteria(filterCriteria))
    }

    public static func withinInclusiveRangeOf(_ filterCriteria: RecordAccessRangeFilterCriteria) -> RecordAccessOperationValue {
        RecordAccessOperationValue(operator: .withinInclusiveRangeOf, operand: .rangeFilterCriteria(filterCriteria))
    }
}


extension RecordAccessGenericOperand: Hashable, Sendable {}
