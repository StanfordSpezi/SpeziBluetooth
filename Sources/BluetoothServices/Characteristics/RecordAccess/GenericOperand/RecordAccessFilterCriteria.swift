//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public enum RecordAccessRangeFilterCriteria {
    case sequenceNumber(min: UInt16, max: UInt16)
    case userFacingTime(min: Int16, max: Int16)


    public var filterType: RecordAccessFilterType {
        switch self {
        case .sequenceNumber:
            return .sequenceNumber
        case .userFacingTime:
            return .userFacingTime
        }
    }
}


public enum RecordAccessFilterCriteria {
    case sequenceNumber(UInt16)
    case userFacingTime(Int16)


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
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let filterType = RecordAccessFilterType(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        switch filterType {
        case .sequenceNumber:
            guard let value = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .sequenceNumber(value)
        case .userFacingTime:
            guard let value = Int16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .userFacingTime(value)
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        filterType.encode(to: &byteBuffer, preferredEndianness: endianness)

        switch self {
        case let .sequenceNumber(value):
            value.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .userFacingTime(value):
            value.encode(to: &byteBuffer, preferredEndianness: endianness)
        }
    }
}


extension RecordAccessRangeFilterCriteria: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let filterType = RecordAccessFilterType(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        switch filterType {
        case .sequenceNumber:
            guard let min = UInt16(from: &byteBuffer, preferredEndianness: endianness),
                  let max = UInt16(from: &byteBuffer, preferredEndianness: endianness)else {
                return nil
            }
            self = .sequenceNumber(min: min, max: max)
        case .userFacingTime:
            guard let min = Int16(from: &byteBuffer, preferredEndianness: endianness),
                  let max = Int16(from: &byteBuffer, preferredEndianness: endianness)else {
                return nil
            }
            self = .userFacingTime(min: min, max: max)
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        filterType.encode(to: &byteBuffer, preferredEndianness: endianness)

        switch self {
        case let .sequenceNumber(min, max):
            min.encode(to: &byteBuffer, preferredEndianness: endianness)
            max.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .userFacingTime(min, max):
            min.encode(to: &byteBuffer, preferredEndianness: endianness)
            max.encode(to: &byteBuffer, preferredEndianness: endianness)
        }
    }
}
