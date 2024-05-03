//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIO


public struct BloodPressureMeasurement {
    fileprivate struct Flags: OptionSet {
        let rawValue: UInt8

        static let kPaUnit = Flags(rawValue: 1 << 0)
        static let timeStampPresent = Flags(rawValue: 1 << 1)
        static let pulseRatePresent = Flags(rawValue: 1 << 2)
        static let userIdPresent = Flags(rawValue: 1 << 3)
        static let measurementStatusPresent = Flags(rawValue: 1 << 4)

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// The unit of a blood pressure measurement.
    public enum Unit { // TODO: apply similar style to temperature measurement!
        /// Blood pressure for Systolic, Diastolic and Mean Arterial Pressure (MAP) is in units of mmHg.
        case mmHg
        /// Blood pressure for Systolic, Diastolic and Mean Arterial Pressure (MAP) is in units of kPa.
        case kPa
    }

    /// Measurement Status of blood pressure measurement.
    ///
    /// Refer to GATT Specification Supplement, 3.31.3 Measurement Status field.
    public struct Status: OptionSet {
        public let rawValue: UInt16

        /// Body movement detected during measurement.
        public static let bodyMovementDetected = Status(rawValue: 1 << 0)
        /// Cuff fit detection detected cuff too loose.
        public static let looseCuffFit = Status(rawValue: 1 << 1)
        /// Irregular pulse detected.
        public static let irregularPulse = Status(rawValue: 1 << 2)
        /// Pulse rate exceeds upper limit.
        public static let pulseRateExceedsUpperLimit = Status(rawValue: 1 << 3) // TODO: are these two switched?
        /// Pulse rate is less than lower limit.
        public static let pulseRateBelowLowerLimit = Status(rawValue: 1 << 4)
        /// Improper measurement position detected.
        public static let improperMeasurementPosition = Status(rawValue: 1 << 5)

        /// Initialize new status option set.
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }

    public let systolicValue: MedFloat16
    public let diastolicValue: MedFloat16
    public let meanArterialPressure: MedFloat16
    public let unit: Unit

    public let timeStamp: DateTime?

    public let pulseRate: MedFloat16?

    public let userId: UInt8? // TODO: checkout usage and behavior

    public let measurementStatus: Status?
}

// TODO: equtable and sendable conformance!

extension BloodPressureMeasurement.Flags: ByteCodable {
    init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension BloodPressureMeasurement.Status: ByteCodable {
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


extension BloodPressureMeasurement: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let flags = Flags(from: &byteBuffer, preferredEndianness: endianness),
              let systolicValue = MedFloat16(from: &byteBuffer, preferredEndianness: endianness),
              let diastolicValue = MedFloat16(from: &byteBuffer, preferredEndianness: endianness),
              let meanArterialPressure = MedFloat16(from: &byteBuffer, preferredEndianness: endianness) else {
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
            guard let timeStamp = DateTime(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self.timeStamp = timeStamp
        } else {
            self.timeStamp = nil
        }

        if flags.contains(.pulseRatePresent) {
            guard let pulseRate = MedFloat16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self.pulseRate = pulseRate
        } else {
            self.pulseRate = nil
        }

        if flags.contains(.userIdPresent) {
            guard let userId = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self.userId = userId
        } else {
            self.userId = nil
        }

        if flags.contains(.measurementStatusPresent) {
            guard let status = Status(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self.measurementStatus = status
        } else {
            self.measurementStatus = nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        var flags: Flags = []

        // write empty flags field for now to move writer index
        let flagsIndex = byteBuffer.writerIndex
        flags.encode(to: &byteBuffer, preferredEndianness: endianness)

        systolicValue.encode(to: &byteBuffer, preferredEndianness: endianness)
        diastolicValue.encode(to: &byteBuffer, preferredEndianness: endianness)
        meanArterialPressure.encode(to: &byteBuffer, preferredEndianness: endianness)

        if case .kPa = unit {
            flags.insert(.kPaUnit)
        }

        if let timeStamp {
            flags.insert(.timeStampPresent)
            timeStamp.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        if let pulseRate {
            flags.insert(.pulseRatePresent)
            pulseRate.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        if let userId {
            flags.insert(.userIdPresent)
            userId.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        if let measurementStatus {
            flags.insert(.measurementStatusPresent)
            measurementStatus.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        byteBuffer.setInteger(flags.rawValue, at: flagsIndex) // finally update the flags field
    }
}
