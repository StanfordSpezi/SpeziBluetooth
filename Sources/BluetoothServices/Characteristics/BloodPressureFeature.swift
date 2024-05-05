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


public struct BloodPressureFeature: OptionSet {
    public var rawValue: UInt16


    /// Indicate if body movement detection is supported.
    ///
    /// If supported, use the ``BloodPressureMeasurement/Status/bodyMovementDetected`` field to indicate if
    /// body movement was detected.
    /// If not supported, the ``BloodPressureMeasurement/Status/bodyMovementDetected`` shall not be set.
    public static let bodyMovementDetectionSupported = BloodPressureFeature(rawValue: 1 << 0)
    /// Indicate if the cuff fit detection is supported.
    ///
    /// If supported, use the ``BloodPressureMeasurement/Status/looseCuffFit`` field to indicate if
    /// loose cuff fit was detected.
    /// If not supported, the ``BloodPressureMeasurement/Status/looseCuffFit`` shall not be set.
    public static let cuffFitDetectionSupported = BloodPressureFeature(rawValue: 1 << 1)
    /// Indicate if the irregular pulse detection is supported.
    ///
    /// If supported, use the ``BloodPressureMeasurement/Status/irregularPulse`` field to indicate if
    /// irregular pulse was detected.
    /// If not supported, the ``BloodPressureMeasurement/Status/irregularPulse`` shall not be set.
    public static let irregularPulseDetectionSupported = BloodPressureFeature(rawValue: 1 << 2)
    /// Indicate if the pulse rate range detection is supported.
    ///
    /// If supported, use the ``BloodPressureMeasurement/Status/pulseRateBelowLowerLimit`` or
    /// ``BloodPressureMeasurement/Status/pulseRateExceedsUpperLimit`` fields to indicate if
    /// if a pulse rate was detected that was out of range.
    /// If not supported, the ``BloodPressureMeasurement/Status/pulseRateBelowLowerLimit``
    /// or ``BloodPressureMeasurement/Status/pulseRateExceedsUpperLimit`` shall not be set.
    public static let pulseRateRangeDetectionSupported = BloodPressureFeature(rawValue: 1 << 3)
    /// Indicate if measurement position detection is supported.
    ///
    /// If supported, use the ``BloodPressureMeasurement/Status/improperMeasurementPosition`` field to indicate
    /// a improper measurement position.
    /// If not supported, the ``BloodPressureMeasurement/Status/improperMeasurementPosition`` shall not be set.
    public static let measurementPositionDetectionSupported = BloodPressureFeature(rawValue: 1 << 4)
    /// Indicate if the blood pressure sensor supports multiple bonds.
    public static let multipleBondsSupported = BloodPressureFeature(rawValue: 1 << 5)
    /// Indicate if the sensors supports E2E protection of blood pressure records with an E2E-CRC.
    public static let e2eCrcSupported = BloodPressureFeature(rawValue: 1 << 6)
    /// Indicate if the User Data Service is supported.
    public static let userDataServiceSupported = BloodPressureFeature(rawValue: 1 << 7)
    /// Indicate if Device Time and User Facing Time reporting using Device Time Service (v1.0 or later).
    public static let userFacingTimeSupported = BloodPressureFeature(rawValue: 1 << 8)


    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}


extension BloodPressureFeature: Hashable, Sendable {}


extension BloodPressureFeature: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
