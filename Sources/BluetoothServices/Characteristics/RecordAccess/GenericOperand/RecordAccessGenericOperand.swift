//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


// TODO: docs and is this topics section right?
/// Asdf
///
/// ## Topics
///
/// ### Generic Implementation
/// - ``RecordAccessFilterType``
/// - ``RecordAccessGeneralResponse``
/// - ``RecordAccessFilterCriteria``
/// - ``RecordAccessRangeFilterCriteria``
public enum RecordAccessGenericOperand {
    // REQUEST
    case filterCriteria(RecordAccessFilterCriteria)
    case rangeFilterCriteria(RecordAccessRangeFilterCriteria)

    /// RESPONSE
    case generalResponse(RecordAccessGeneralResponse)
    case numberOfRecords(UInt16)
}


extension RecordAccessGenericOperand: RecordAccessOperand {
    public var generalResponse: RecordAccessGeneralResponse? {
        guard case let .generalResponse(response) = self else {
            return nil
        }
        return response
    }

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


extension RecordAccessOperationContent where Operand == RecordAccessGenericOperand {
    public static func lessThanOrEqualTo(_ filterCriteria: RecordAccessFilterCriteria) -> RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .lessThanOrEqualTo, operand: .filterCriteria(filterCriteria))
    }

    public static func greaterThanOrEqualToRecordAccessFilterCriteriaNew(_ filterCriteria: RecordAccessFilterCriteria) -> RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .greaterThanOrEqual, operand: .filterCriteria(filterCriteria))
    }

    public static func withinInclusiveRangeOf(_ filterCriteria: RecordAccessRangeFilterCriteria) -> RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .withinInclusiveRangeOf, operand: .rangeFilterCriteria(filterCriteria))
    }
}


extension RecordAccessGenericOperand: Hashable, Sendable {}
