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
import SpeziNumerics


/// A blood pressure measurement.
///
/// Refer to GATT Specification Supplement, 3.31 Blood Pressure Measurement.
public struct BloodPressureMeasurement {
    fileprivate struct Flags: OptionSet {
        static let kPaUnit = Flags(rawValue: 1 << 0)
        static let timeStampPresent = Flags(rawValue: 1 << 1)
        static let pulseRatePresent = Flags(rawValue: 1 << 2)
        static let userIdPresent = Flags(rawValue: 1 << 3)
        static let measurementStatusPresent = Flags(rawValue: 1 << 4)

        let rawValue: UInt8

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// The unit of a blood pressure measurement.
    public enum Unit: String {
        /// Blood pressure for Systolic, Diastolic and Mean Arterial Pressure (MAP) is in units of mmHg.
        case mmHg
        /// Blood pressure for Systolic, Diastolic and Mean Arterial Pressure (MAP) is in units of kPa.
        case kPa
    }

    /// Measurement Status of blood pressure measurement.
    ///
    /// Refer to GATT Specification Supplement, 3.31.3 Measurement Status field.
    public struct Status: OptionSet {
        /// Body movement detected during measurement.
        public static let bodyMovementDetected = Status(rawValue: 1 << 0)
        /// Cuff fit detection detected cuff too loose.
        public static let looseCuffFit = Status(rawValue: 1 << 1)
        /// Irregular pulse detected.
        public static let irregularPulse = Status(rawValue: 1 << 2)
        /// Pulse rate exceeds upper limit.
        public static let pulseRateExceedsUpperLimit = Status(rawValue: 1 << 3)
        /// Pulse rate is less than lower limit.
        public static let pulseRateBelowLowerLimit = Status(rawValue: 1 << 4)
        /// Improper measurement position detected.
        public static let improperMeasurementPosition = Status(rawValue: 1 << 5)

        public let rawValue: UInt16

        /// Initialize new status option set.
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }

    /// The systolic value of the blood pressure measurement.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public let systolicValue: MedFloat16
    /// The diastolic value of the blood pressure measurement.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public let diastolicValue: MedFloat16
    /// The Mean Arterial Pressure (MAP)
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public let meanArterialPressure: MedFloat16
    /// The unit of the blood pressure measurement values.
    ///
    /// This property defines the unit of the ``systolicValue``, ``diastolicValue`` and ``meanArterialPressure`` properties.
    public let unit: Unit

    /// The timestamp of the measurement.
    public let timeStamp: DateTime?

    /// The pulse rate in beats per minute.
    public let pulseRate: MedFloat16?

    /// The associated user of the blood pressure measurement.
    ///
    /// This value can be used to differentiate users if the device supports multiple users.
    /// - Note: The special value of `0xFF` (`UInt8.max`) is used to represent an unknown user.
    ///
    /// The values are left to the implementation but should be unique per device.
    public let userId: UInt8?

    /// Additional metadata information of a blood pressure measurement.
    public let measurementStatus: Status?


    /// Create a new blood pressure measurement.
    /// - Parameters:
    ///   - systolicValue: The systolic blood pressure value.
    ///     An unavailable value can be indicated using [`MedFloat16/nan`](https://swiftpackageindex.com/stanfordspezi/spezinetworking/documentation/spezinumerics/medfloat16/nan).
    ///   - diastolicValue: The diastolic blood pressure value.
    ///     An unavailable value can be indicated using [`MedFloat16/nan`](https://swiftpackageindex.com/stanfordspezi/spezinetworking/documentation/spezinumerics/medfloat16/nan).
    ///   - meanArterialPressure: The mean arterial pressure.
    ///     An unavailable value can be indicated using [`MedFloat16/nan`](https://swiftpackageindex.com/stanfordspezi/spezinetworking/documentation/spezinumerics/medfloat16/nan).
    ///   - unit: The unit for the systolic, diastolic and mean arterial pressure values.
    ///   - timeStamp: The timestamp of the measurement.
    ///     The value should be provided if the device supports storage of data.
    ///   - pulseRate: The pulse rate in in beats per minute.
    ///     An unavailable value can be indicated using [`MedFloat16/nan`](https://swiftpackageindex.com/stanfordspezi/spezinetworking/documentation/spezinumerics/medfloat16/nan).
    ///   - userId: The associated user of the blood pressure measurement.
    ///   - measurementStatus: Additional metadata information of the measurement.
    public init(
        systolic systolicValue: MedFloat16,
        diastolic diastolicValue: MedFloat16,
        meanArterialPressure: MedFloat16,
        unit: Unit,
        timeStamp: DateTime? = nil,
        pulseRate: MedFloat16? = nil,
        userId: UInt8? = nil,
        measurementStatus: Status? = nil
    ) {
        self.systolicValue = systolicValue
        self.diastolicValue = diastolicValue
        self.meanArterialPressure = meanArterialPressure
        self.unit = unit
        self.timeStamp = timeStamp
        self.pulseRate = pulseRate
        self.userId = userId
        self.measurementStatus = measurementStatus
    }
}


extension BloodPressureMeasurement.Unit: Sendable, Hashable {}


extension BloodPressureMeasurement.Status: Sendable, Hashable {}


extension BloodPressureMeasurement: Sendable, Hashable {}


extension BloodPressureMeasurement.Status: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        var components: [String] = []
        if contains(.bodyMovementDetected) {
            components.append("bodyMovementDetected")
        }
        if contains(.looseCuffFit) {
            components.append("looseCuffFit")
        }
        if contains(.irregularPulse) {
            components.append("irregularPulse")
        }
        if contains(.pulseRateExceedsUpperLimit) {
            components.append("pulseRateExceedsUpperLimit")
        }
        if contains(.pulseRateBelowLowerLimit) {
            components.append("pulseRateBelowLowerLimit")
        }
        if contains(.improperMeasurementPosition) {
            components.append("improperMeasurementPosition")
        }
        return "[\(components.joined(separator: ", "))]"
    }

    public var debugDescription: String {
        "\(Self.self)(rawValue: 0x\(String(format: "%02X", rawValue)))"
    }
}


extension BloodPressureMeasurement.Flags: ByteCodable {
    init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt8(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension BloodPressureMeasurement.Status: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt16(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension BloodPressureMeasurement: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let flags = Flags(from: &byteBuffer),
              let systolicValue = MedFloat16(from: &byteBuffer),
              let diastolicValue = MedFloat16(from: &byteBuffer),
              let meanArterialPressure = MedFloat16(from: &byteBuffer) else {
            return nil
        }

        self.systolicValue = systolicValue
        self.diastolicValue = diastolicValue
        self.meanArterialPressure = meanArterialPressure

        if flags.contains(.kPaUnit) {
            self.unit = .kPa
        } else {
            self.unit = .mmHg
        }

        if flags.contains(.timeStampPresent) {
            guard let timeStamp = DateTime(from: &byteBuffer) else {
                return nil
            }
            self.timeStamp = timeStamp
        } else {
            self.timeStamp = nil
        }

        if flags.contains(.pulseRatePresent) {
            guard let pulseRate = MedFloat16(from: &byteBuffer) else {
                return nil
            }
            self.pulseRate = pulseRate
        } else {
            self.pulseRate = nil
        }

        if flags.contains(.userIdPresent) {
            guard let userId = UInt8(from: &byteBuffer) else {
                return nil
            }
            self.userId = userId
        } else {
            self.userId = nil
        }

        if flags.contains(.measurementStatusPresent) {
            guard let status = Status(from: &byteBuffer) else {
                return nil
            }
            self.measurementStatus = status
        } else {
            self.measurementStatus = nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        var flags: Flags = []

        // write empty flags field for now to move writer index
        let flagsIndex = byteBuffer.writerIndex
        flags.encode(to: &byteBuffer)

        systolicValue.encode(to: &byteBuffer)
        diastolicValue.encode(to: &byteBuffer)
        meanArterialPressure.encode(to: &byteBuffer)

        if case .kPa = unit {
            flags.insert(.kPaUnit)
        }

        if let timeStamp {
            flags.insert(.timeStampPresent)
            timeStamp.encode(to: &byteBuffer)
        }

        if let pulseRate {
            flags.insert(.pulseRatePresent)
            pulseRate.encode(to: &byteBuffer)
        }

        if let userId {
            flags.insert(.userIdPresent)
            userId.encode(to: &byteBuffer)
        }

        if let measurementStatus {
            flags.insert(.measurementStatusPresent)
            measurementStatus.encode(to: &byteBuffer)
        }

        byteBuffer.setInteger(flags.rawValue, at: flagsIndex) // finally update the flags field
    }
}


extension BloodPressureMeasurement.Unit: Codable {}


extension BloodPressureMeasurement.Status: Codable {}


extension BloodPressureMeasurement: Codable {}
