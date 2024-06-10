//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// A generic Record Access Operand used with most Bluetooth services.
///
/// Most of the standardized Bluetooth services using the Access Control Control Point characteristic,
/// like the Glucose Service or the Enhanced Blood Pressure Service, use this generic operand format.
///
/// The format depends on the specific ``RecordAccessOpCode`` and ``RecordAccessOperator``.
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

    /// The filter criteria used in requests with the ``RecordAccessOperator/lessThanOrEqualTo`` and ``RecordAccessOperator/greaterThanOrEqual`` operator.
    ///
    /// This operator and operand are used with the ``RecordAccessOpCode/reportStoredRecords``, ``RecordAccessOpCode/deleteStoredRecords`` or
    /// ``RecordAccessOpCode/reportNumberOfStoredRecords`` operations.
    case filterCriteria(RecordAccessFilterCriteria)
    /// The range filter criteria used in requests with the ``RecordAccessOperator/withinInclusiveRangeOf`` operator.
    ///
    /// This operator and operand are used with the ``RecordAccessOpCode/reportStoredRecords``, ``RecordAccessOpCode/deleteStoredRecords`` or
    /// ``RecordAccessOpCode/reportNumberOfStoredRecords`` operations.
    case rangeFilterCriteria(RecordAccessRangeFilterCriteria)

    // RESPONSE


    /// The general response operand used with the ``RecordAccessOpCode/responseCode`` operation.
    case generalResponse(RecordAccessGeneralResponse)
    /// Reports the number of records in the ``RecordAccessOpCode/numberOfStoredRecordsResponse`` operation.
    case numberOfRecords(UInt16)
}


extension RecordAccessGenericOperand: RecordAccessOperand {
    public var generalResponse: RecordAccessGeneralResponse? {
        guard case let .generalResponse(response) = self else {
            return nil
        }
        return response
    }

    public init?( // swiftlint:disable:this cyclomatic_complexity
        from byteBuffer: inout ByteBuffer,
        opCode: RecordAccessOpCode,
        operator: RecordAccessOperator
    ) {
        switch opCode {
        case .responseCode:
            guard let response = RecordAccessGeneralResponse(from: &byteBuffer) else {
                return nil
            }
            self = .generalResponse(response)
        case .reportStoredRecords, .deleteStoredRecords, .reportNumberOfStoredRecords:
            switch `operator` {
            case .lessThanOrEqualTo, .greaterThanOrEqual:
                guard let filterCriteria = RecordAccessFilterCriteria(from: &byteBuffer) else {
                    return nil
                }
                self = .filterCriteria(filterCriteria)
            case .withinInclusiveRangeOf:
                guard let filterCriteria = RecordAccessRangeFilterCriteria(from: &byteBuffer) else {
                    return nil
                }
                self = .rangeFilterCriteria(filterCriteria)
            default:
                return nil
            }
        case .numberOfStoredRecordsResponse:
            guard let count = UInt16(from: &byteBuffer) else {
                return nil
            }
            self = .numberOfRecords(count)
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        switch self {
        case let .generalResponse(response):
            response.encode(to: &byteBuffer)
        case let .filterCriteria(criteria):
            criteria.encode(to: &byteBuffer)
        case let .rangeFilterCriteria(criteria):
            criteria.encode(to: &byteBuffer)
        case let .numberOfRecords(value):
            value.encode(to: &byteBuffer)
        }
    }
}


extension RecordAccessOperationContent where Operand == RecordAccessGenericOperand {
    /// Records that are less than or equal to the specified filter criteria value.
    ///
    /// - Parameter filterCriteria: The filter criteria.
    /// - Returns: The operation content.
    public static func lessThanOrEqualTo(_ filterCriteria: RecordAccessFilterCriteria) -> RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .lessThanOrEqualTo, operand: .filterCriteria(filterCriteria))
    }

    /// Records that are greater than or equal to the specified filter criteria value.
    public static func greaterThanOrEqualTo(_ filterCriteria: RecordAccessFilterCriteria) -> RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .greaterThanOrEqual, operand: .filterCriteria(filterCriteria))
    }

    /// Records that are within the closed range of the specified filter criteria value.
    public static func withinInclusiveRangeOf(_ filterCriteria: RecordAccessRangeFilterCriteria) -> RecordAccessOperationContent {
        RecordAccessOperationContent(operator: .withinInclusiveRangeOf, operand: .rangeFilterCriteria(filterCriteria))
    }
}


extension RecordAccessGenericOperand: Hashable, Sendable {}
