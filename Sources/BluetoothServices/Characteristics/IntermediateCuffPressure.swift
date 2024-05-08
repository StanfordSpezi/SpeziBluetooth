//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore


/// Intermediate cuff pressure values while  a measurement is in progress.
///
/// The intermediate cuff pressure characteristic is used to send intermediate cuff pressure values to a device
/// for displaying purposes while a blood pressure measurement is in progress.
///
/// Refer to GATT Specification Supplement, 3.126 Intermediate Cuff Pressure.
public struct IntermediateCuffPressure {
    /// The  intermediate cuff pressure has the same format as the blood pressure measurement characteristic.
    ///
    /// Some of the fields have different semantics in the context of the intermediate cuff pressure characteristic.
    /// The systolic blood pressure field is used as the current cuff pressure, while the other fields (diastolic and mean arterial pressure)
    /// are unused and are set to NaN.
    private let representation: BloodPressureMeasurement

    /// The current cuff pressure.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public var currentCuffPressure: MedFloat16 {
        representation.systolicValue
    }

    /// The unit of the current cuff pressure.
    public var unit: BloodPressureMeasurement.Unit {
        representation.unit
    }

    /// Timestamp that may be included.
    ///
    /// It is recommended to not be used to avoid sending unnecessary data.
    public var timestamp: DateTime? {
        representation.timeStamp
    }

    /// The current pulse rate.
    ///
    /// It is recommended to not be used to avoid sending unnecessary data.
    public var pulseRate: MedFloat16? {
        representation.pulseRate
    }

    /// The associated user of the blood pressure measurement.
    ///
    /// This value can be used to differentiate users if the device supports multiple users.
    /// - Note: The special value of `0xFF` (`UInt8.max`) is used to represent an unknown user.
    ///
    /// The values are left to the implementation but should be unique per device.
    public var userId: UInt8? {
        representation.userId
    }

    /// Additional metadata information of a blood pressure measurement.
    public var measurementStatus: BloodPressureMeasurement.Status? {
        representation.measurementStatus
    }


    /// Create a new intermediate cuff pressure value.
    /// - Parameters:
    ///   - currentCuffPressure: The current cuff pressure.
    ///   - unit: The unit of the current cuff pressure.
    ///   - timeStamp: The timestamp of the measurement.
    ///     Do not provide a value to avoid transmitting unnecessary data.
    ///   - pulseRate: The current pulse rate.
    ///     Do not provide a value to avoid transmitting unnecessary data.
    ///   - userId: The associated user of the blood pressure measurement.
    ///   - measurementStatus: Additional metadata information of the measurement.
    public init(
        currentCuffPressure: MedFloat16,
        unit: BloodPressureMeasurement.Unit,
        timeStamp: DateTime? = nil,
        pulseRate: MedFloat16? = nil,
        userId: UInt8? = nil,
        measurementStatus: BloodPressureMeasurement.Status? = nil
    ) {
        self.representation = BloodPressureMeasurement(
            systolic: currentCuffPressure,
            diastolic: .nan,
            meanArterialPressure: .nan,
            unit: unit,
            timeStamp: timeStamp,
            pulseRate: pulseRate,
            userId: userId,
            measurementStatus: measurementStatus
        )
    }
}


extension IntermediateCuffPressure: Hashable, Sendable {
    public static func == (lhs: IntermediateCuffPressure, rhs: IntermediateCuffPressure) -> Bool {
        // we need to override the implementation to avoid weird behavior with NaNs
        lhs.currentCuffPressure == rhs.currentCuffPressure
            && lhs.unit == rhs.unit
            && lhs.timestamp == rhs.timestamp
            && lhs.pulseRate == rhs.pulseRate
            && lhs.userId == rhs.userId
            && lhs.measurementStatus == rhs.measurementStatus
    }
}


extension IntermediateCuffPressure: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let representation = BloodPressureMeasurement(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.representation = representation
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        representation.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
