//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// Represents the time between measurements.
///
/// Refer to GATT Specification Supplement, 3.150 Measurement Interval.
public enum MeasurementInterval {
    /// No periodic measurement
    case noPeriodicMeasurement
    /// Duration of measurement interval.
    case duration(_ seconds: UInt16)
}


extension MeasurementInterval: Hashable, Sendable {}


extension MeasurementInterval: RawRepresentable {
    public var rawValue: UInt16 {
        switch self {
        case .noPeriodicMeasurement:
            0
        case let .duration(seconds):
            seconds
        }
    }

    public init(rawValue: UInt16) {
        switch rawValue {
        case 0:
            self = .noPeriodicMeasurement
        default:
            self = .duration(rawValue)
        }
    }
}


extension MeasurementInterval: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let value = UInt16(from: &byteBuffer) else {
            return nil
        }

        self.init(rawValue: value)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension MeasurementInterval: Codable {}
