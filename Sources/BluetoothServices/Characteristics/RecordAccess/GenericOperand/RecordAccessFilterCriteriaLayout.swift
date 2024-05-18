//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


// TODO: docs
public struct RecordAccessFilterCriteriaScalar<Value: ByteCodable>: RecordAccessFilterCriteriaLayout {
    public let filterType: RecordAccessFilterType
    public let value: Value

    init(filterType: RecordAccessFilterType, value: Value) {
        self.filterType = filterType
        self.value = value
    }
}


// TODO: docs
public struct RecordAccessFilterCriteriaTuple<InnerValue: ByteCodable>: RecordAccessFilterCriteriaLayout {
    public struct Value {
        public let lhs: InnerValue
        public let rhs: InnerValue

        init(lhs: InnerValue, rhs: InnerValue) {
            self.lhs = lhs
            self.rhs = rhs
        }
    }


    public let filterType: RecordAccessFilterType
    let value: Value

    public var lhs: InnerValue {
        value.lhs
    }

    public var rhs: InnerValue {
        value.rhs
    }


    init(filterType: RecordAccessFilterType, value: Value) {
        self.filterType = filterType
        self.value = value
    }
}


protocol RecordAccessFilterCriteriaLayout: ByteEncodable { // TODO: docs!
    associatedtype Value: ByteCodable

    var filterType: RecordAccessFilterType { get }
    var value: Value { get }

    init(filterType: RecordAccessFilterType, value: Value)

    init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness, filterType: RecordAccessFilterType)
}


extension RecordAccessFilterCriteriaLayout {
    init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness, filterType: RecordAccessFilterType) {
        guard let value = Value(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(filterType: filterType, value: value)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        filterType.encode(to: &byteBuffer, preferredEndianness: endianness)
        value.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension RecordAccessFilterCriteriaTuple.Value: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let lhs = InnerValue(from: &byteBuffer, preferredEndianness: endianness),
              let rhs = InnerValue(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(lhs: lhs, rhs: rhs)
    }


    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        lhs.encode(to: &byteBuffer, preferredEndianness: endianness)
        rhs.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension RecordAccessFilterCriteriaScalar where Value == UInt16 {
    public static func sequenceNumber(_ value: UInt16) -> RecordAccessFilterCriteriaScalar {
        RecordAccessFilterCriteriaScalar(filterType: .sequenceNumber, value: value)
    }
}


extension RecordAccessFilterCriteriaScalar where Value == Int16 {
    public static func userFacingTime(_ value: Int16) -> RecordAccessFilterCriteriaScalar {
        RecordAccessFilterCriteriaScalar(filterType: .userFacingTime, value: value)
    }
}


extension RecordAccessFilterCriteriaTuple where InnerValue == UInt16 {
    public static func sequenceNumber(min: UInt16, max: UInt16) -> RecordAccessFilterCriteriaTuple {
        RecordAccessFilterCriteriaTuple(filterType: .sequenceNumber, value: Value(lhs: min, rhs: max))
    }
}


extension RecordAccessFilterCriteriaTuple where InnerValue == Int16 {
    public static func userFacingTime(min: Int16, max: Int16) -> RecordAccessFilterCriteriaTuple {
        RecordAccessFilterCriteriaTuple(filterType: .sequenceNumber, value: Value(lhs: min, rhs: max))
    }
}
