//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public struct RecordAccessFilterCriteria {
    private let layout: any RecordAccessFilterCriteriaLayout

    public var filterType: RecordAccessFilterType {
        layout.filterType
    }

    public var value: any ByteCodable {
        layout.value
    }

    init(_ criteria: any RecordAccessFilterCriteriaLayout) {
        self.layout = criteria
    }
}


extension RecordAccessFilterCriteria {
    public init?( // swiftlint:disable:this cyclomatic_complexity
                  from byteBuffer: inout ByteBuffer,
                  preferredEndianness endianness: Endianness,
                  operator: RecordAccessOperator
    ) {
        let criteria: (any RecordAccessFilterCriteriaLayout)?

        switch `operator` {
        case .lessThanOrEqualTo, .greaterThanOrEqual:
            guard let filterType = RecordAccessFilterType(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }

            switch filterType {
            case .sequenceNumber:
                criteria = RecordAccessFilterCriteriaScalar<UInt16>(from: &byteBuffer, preferredEndianness: endianness, filterType: filterType)
            case .userFacingTime:
                criteria = RecordAccessFilterCriteriaScalar<Int16>(from: &byteBuffer, preferredEndianness: endianness, filterType: filterType)
            default:
                return nil
            }
        case .withinInclusiveRangeOf:
            guard let filterType = RecordAccessFilterType(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }

            switch filterType {
            case .sequenceNumber:
                criteria = RecordAccessFilterCriteriaTuple<UInt16>(from: &byteBuffer, preferredEndianness: endianness, filterType: filterType)
            case .userFacingTime:
                criteria = RecordAccessFilterCriteriaTuple<Int16>(from: &byteBuffer, preferredEndianness: endianness, filterType: filterType)
            default:
                return nil
            }
        default:
            return nil
        }

        guard let criteria else {
            return nil
        }

        self.init(criteria)
    }
}


extension RecordAccessFilterCriteria: ByteEncodable {
    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        layout.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
