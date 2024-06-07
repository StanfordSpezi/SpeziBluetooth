//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices
import NIOCore


/// The Record Access Operand format for the Omron Record Access Control Point characteristic.
public enum OmronRecordAccessOperand {
    // REQUEST

    /// Specify filter criteria for supported requests.
    ///
    /// For more information refer to ``RecordAccessGenericOperand``.
    case filterCriteria(RecordAccessFilterCriteria)
    /// Specify range-based filter criteria for supported requests.
    ///
    /// For more information refer to ``RecordAccessGenericOperand``.
    case rangeFilterCriteria(RecordAccessRangeFilterCriteria)

    // RESPONSE

    /// The general response operand used with the ``RecordAccessOpCode/responseCode`` operation.
    case generalResponse(RecordAccessGeneralResponse)
    /// Reports the number of records in the ``RecordAccessOpCode/numberOfStoredRecordsResponse`` operation.
    case numberOfRecords(UInt16)
    /// Reports the sequence number of the latest records in the ``BluetoothServices/RecordAccessOpCode/omronSequenceNumberOfLatestRecordsResponse`` operation.
    case sequenceNumber(UInt16)
}


extension OmronRecordAccessOperand: RecordAccessOperand {
    public var generalResponse: RecordAccessGeneralResponse? {
        guard case let .generalResponse(response) = self else {
            return nil
        }
        return response
    }

    public init?( // swiftlint:disable:this cyclomatic_complexity
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
        case .omronSequenceNumberOfLatestRecordsResponse:
            guard let sequenceNumber = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .sequenceNumber(sequenceNumber)
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
        case let .numberOfRecords(value), let .sequenceNumber(value):
            value.encode(to: &byteBuffer, preferredEndianness: endianness)
        }
    }
}
