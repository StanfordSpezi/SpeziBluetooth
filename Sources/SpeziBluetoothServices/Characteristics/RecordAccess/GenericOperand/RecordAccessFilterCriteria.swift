//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// Range-based filter criteria format for the generic operand.
///
/// The filter criteria format used with the ``RecordAccessGenericOperand``.
public enum RecordAccessRangeFilterCriteria {
    /// Filter records for range of sequence numbers.
    case sequenceNumber(min: UInt16, max: UInt16)
    /// Filter records for range of user facing time.
    case userFacingTime(min: Int16, max: Int16)


    /// The filter type code.+
    public var filterType: RecordAccessFilterType {
        switch self {
        case .sequenceNumber:
            return .sequenceNumber
        case .userFacingTime:
            return .userFacingTime
        }
    }
}


/// Filter criteria format for the generic operand.
///
/// The filter criteria format used with the ``RecordAccessGenericOperand``.
public enum RecordAccessFilterCriteria {
    /// Filter for the record's sequence number.
    case sequenceNumber(UInt16)
    /// Filter for the record's user facing time.
    case userFacingTime(Int16)


    /// The filter type code.
    public var filterType: RecordAccessFilterType {
        switch self {
        case .sequenceNumber:
            return .sequenceNumber
        case .userFacingTime:
            return .userFacingTime
        }
    }
}


extension RecordAccessFilterCriteria: Hashable, Sendable {}


extension RecordAccessRangeFilterCriteria: Hashable, Sendable {}


extension RecordAccessFilterCriteria: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let filterType = RecordAccessFilterType(from: &byteBuffer) else {
            return nil
        }

        switch filterType {
        case .sequenceNumber:
            guard let value = UInt16(from: &byteBuffer) else {
                return nil
            }
            self = .sequenceNumber(value)
        case .userFacingTime:
            guard let value = Int16(from: &byteBuffer) else {
                return nil
            }
            self = .userFacingTime(value)
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        filterType.encode(to: &byteBuffer)

        switch self {
        case let .sequenceNumber(value):
            value.encode(to: &byteBuffer)
        case let .userFacingTime(value):
            value.encode(to: &byteBuffer)
        }
    }
}


extension RecordAccessRangeFilterCriteria: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let filterType = RecordAccessFilterType(from: &byteBuffer) else {
            return nil
        }

        switch filterType {
        case .sequenceNumber:
            guard let min = UInt16(from: &byteBuffer),
                  let max = UInt16(from: &byteBuffer) else {
                return nil
            }
            self = .sequenceNumber(min: min, max: max)
        case .userFacingTime:
            guard let min = Int16(from: &byteBuffer),
                  let max = Int16(from: &byteBuffer) else {
                return nil
            }
            self = .userFacingTime(min: min, max: max)
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        filterType.encode(to: &byteBuffer)

        switch self {
        case let .sequenceNumber(min, max):
            min.encode(to: &byteBuffer)
            max.encode(to: &byteBuffer)
        case let .userFacingTime(min, max):
            min.encode(to: &byteBuffer)
            max.encode(to: &byteBuffer)
        }
    }
}
