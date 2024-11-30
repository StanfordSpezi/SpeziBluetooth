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


/// A PLX Continuous Measurement, as defined in the [Bluetooth specification](https://www.bluetooth.com/specifications/specs/plxs-html/).
public struct PLXContinuousMeasurement: ByteCodable, Hashable, Sendable, Codable {
    struct Flags: OptionSet, ByteCodable, Sendable, Codable, Hashable {
        let rawValue: UInt8
        
        static let hasSpO2PRFast = Self(rawValue: 1 << 0)
        static let hasSpO2PRSlow = Self(rawValue: 1 << 1)
        static let hasMeasurementStatus = Self(rawValue: 1 << 2)
        static let hasDeviceAndSensorStatus = Self(rawValue: 1 << 3)
        static let hasPulseAmplitudeIndex = Self(rawValue: 1 << 4)
    }
    
    /// Information about the status of the measurement.
    public struct MeasurementStatus: OptionSet, PrimitiveByteCodable, Sendable, Codable, Hashable {
        public let rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
        
        public static let measurementIsOngoing = Self(rawValue: 1 << 5)
        public static let earlyEstimatedData = Self(rawValue: 1 << 6)
        public static let validatedData = Self(rawValue: 1 << 7)
        public static let fullyQualifiedData = Self(rawValue: 1 << 8)
        public static let dataFromMeasurementStorage = Self(rawValue: 1 << 9)
        public static let dataForDemonstration = Self(rawValue: 1 << 10)
        public static let dataForTesting = Self(rawValue: 1 << 11)
        public static let calibrationOngoing = Self(rawValue: 1 << 12)
        public static let measurementUnavailable = Self(rawValue: 1 << 13)
        public static let questionableMeasurementDetected = Self(rawValue: 1 << 14)
        public static let invalidMeasurementDetected = Self(rawValue: 1 << 15)
    }
    
    /// Device-level information about the sensor.
    public struct DeviceAndSensorStatus: OptionSet, ByteCodable, Sendable, Codable, Hashable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        public static let extendedDisplayUpdateOngoing = Self(rawValue: 1 << 0)
        public static let equipmentMalfunctionDetected = Self(rawValue: 1 << 1)
        public static let signalProcessingIrregularityDetected = Self(rawValue: 1 << 2)
        public static let inadequateSignalDetected = Self(rawValue: 1 << 3)
        public static let poorSignalDetected = Self(rawValue: 1 << 4)
        public static let lowPerfusionDetected = Self(rawValue: 1 << 5)
        public static let erraticSignalDetected = Self(rawValue: 1 << 6)
        public static let nonpulsatileSignalDetected = Self(rawValue: 1 << 7)
        public static let questionablePulseDetected = Self(rawValue: 1 << 8)
        public static let signalAnalysisOngoing = Self(rawValue: 1 << 9)
        public static let sensorInterferenceDetected = Self(rawValue: 1 << 10)
        public static let sensorUnconnectedToUser = Self(rawValue: 1 << 11)
        public static let unknownSensorConnected = Self(rawValue: 1 << 12)
        public static let sensorDisplaced = Self(rawValue: 1 << 13)
        public static let sensorMalfunctioning = Self(rawValue: 1 << 14)
        public static let sensorDisconnected = Self(rawValue: 1 << 15)
        public static let reservedForFutureUse = Self(rawValue: 0xFFFF0000)
        
        public init?(from byteBuffer: inout ByteBuffer) {
            guard let bytes = byteBuffer.readBytes(length: 3) else {
                return nil
            }
            let rawValue: UInt32 = (UInt32(bytes[2]) << 16) | (UInt32(bytes[1]) << 8) | UInt32(bytes[0])
            self.init(rawValue: rawValue)
        }
        
        public func encode(to byteBuffer: inout ByteBuffer) {
            byteBuffer.writeBytes([
                UInt8(truncatingIfNeeded: rawValue),
                UInt8(truncatingIfNeeded: rawValue >> 8),
                UInt8(truncatingIfNeeded: rawValue >> 16)
            ])
        }
    }
    
    
    /// The measured blood oxygen saturation
    /// Unit: percentage, with a resolution of 1.
    public let oxygenSaturation: MedFloat16
    /// The measured heart rate, in beats per minute.
    public let pulseRate: MedFloat16
    
    /// If available, the fast responding oximetry measurements of the sensor.
    /// Unit: percentage, with a resolution of 1.
    public let oxygenSaturationFast: MedFloat16?
    /// If available, the fast responding oximetry measurements of the sensor.
    /// The measured heart rate, in beats per minute.
    public let pulseRateFast: MedFloat16?
    
    /// If available, the slow responding oximetry measurements of the sensor.
    /// The measured heart rate, in beats per minute.
    public let oxygenSaturationSlow: MedFloat16?
    /// If available, the slow responding oximetry measurements of the sensor.
    /// The measured heart rate, in beats per minute.
    public let pulseRateSlow: MedFloat16?
    
    /// Measurement status flags.
    public let measurementStatus: MeasurementStatus?
    /// Device status flags.
    public let deviceAndSensorStatus: DeviceAndSensorStatus?
    /// Percentage indicating a user's perfusion level (amount of blood being delivered to the capillary bed).
    public let pulseAmplitudeIndex: MedFloat16?
    
    
    /// Creates a new ``PLXContinuousMeasurement`` with the specified values.
    public init(
        oxygenSaturation: MedFloat16,
        pulseRate: MedFloat16,
        oxygenSaturationFast: MedFloat16? = nil,
        pulseRateFast: MedFloat16? = nil,
        oxygenSaturationSlow: MedFloat16? = nil,
        pulseRateSlow: MedFloat16? = nil,
        measurementStatus: MeasurementStatus? = nil,
        deviceAndSensorStatus: DeviceAndSensorStatus? = nil,
        pulseAmplitudeIndex: MedFloat16? = nil
    ) {
        self.oxygenSaturation = oxygenSaturation
        self.pulseRate = pulseRate
        self.oxygenSaturationFast = oxygenSaturationFast
        self.pulseRateFast = pulseRateFast
        self.oxygenSaturationSlow = oxygenSaturationSlow
        self.pulseRateSlow = pulseRateSlow
        self.measurementStatus = measurementStatus
        self.deviceAndSensorStatus = deviceAndSensorStatus
        self.pulseAmplitudeIndex = pulseAmplitudeIndex
    }
    
    
    public init?(from byteBuffer: inout NIOCore.ByteBuffer) { // swiftlint:disable:this function_body_length cyclomatic_complexity
        guard let flags = Flags(from: &byteBuffer) else {
            return nil
        }
        if let oxygen = MedFloat16(from: &byteBuffer),
           let pulse = MedFloat16(from: &byteBuffer) {
            self.oxygenSaturation = oxygen
            self.pulseRate = pulse
        } else {
            return nil
        }
        if flags.contains(.hasSpO2PRFast) {
            guard let oxygen = MedFloat16(from: &byteBuffer),
                  let pulseRate = MedFloat16(from: &byteBuffer) else {
                return nil
            }
            self.oxygenSaturationFast = oxygen
            self.pulseRateFast = pulseRate
        } else {
            self.oxygenSaturationFast = nil
            self.pulseRateFast = nil
        }
        if flags.contains(.hasSpO2PRSlow) {
            guard let oxygen = MedFloat16(from: &byteBuffer),
                  let pulseRate = MedFloat16(from: &byteBuffer) else {
                return nil
            }
            self.oxygenSaturationSlow = oxygen
            self.pulseRateSlow = pulseRate
        } else {
            self.oxygenSaturationSlow = nil
            self.pulseRateSlow = nil
        }
        if flags.contains(.hasMeasurementStatus) {
            guard let status = MeasurementStatus(from: &byteBuffer) else {
                return nil
            }
            self.measurementStatus = status
        } else {
            self.measurementStatus = nil
        }
        if flags.contains(.hasDeviceAndSensorStatus) {
            guard let status = DeviceAndSensorStatus(from: &byteBuffer) else {
                return nil
            }
            self.deviceAndSensorStatus = status
        } else {
            self.deviceAndSensorStatus = nil
        }
        if flags.contains(.hasPulseAmplitudeIndex) {
            guard let index = MedFloat16(from: &byteBuffer) else {
                return nil
            }
            self.pulseAmplitudeIndex = index
        } else {
            self.pulseAmplitudeIndex = nil
        }
    }
    
    
    public func encode(to byteBuffer: inout ByteBuffer) {
        let flags: Flags = {
            var flags = Flags()
            if oxygenSaturationFast != nil, pulseRateFast != nil {
                flags.insert(.hasSpO2PRFast)
            }
            if oxygenSaturationSlow != nil, pulseRateSlow != nil {
                flags.insert(.hasSpO2PRSlow)
            }
            if measurementStatus != nil {
                flags.insert(.hasMeasurementStatus)
            }
            if deviceAndSensorStatus != nil {
                flags.insert(.hasDeviceAndSensorStatus)
            }
            if pulseAmplitudeIndex != nil {
                flags.insert(.hasPulseAmplitudeIndex)
            }
            return flags
        }()
        flags.encode(to: &byteBuffer)
        oxygenSaturation.encode(to: &byteBuffer)
        pulseRate.encode(to: &byteBuffer)
        
        if let oxygenSaturationFast, let pulseRateFast {
            oxygenSaturationFast.encode(to: &byteBuffer)
            pulseRateFast.encode(to: &byteBuffer)
        }
        if let oxygenSaturationSlow, let pulseRateSlow {
            oxygenSaturationSlow.encode(to: &byteBuffer)
            pulseRateSlow.encode(to: &byteBuffer)
        }
        if let measurementStatus {
            measurementStatus.encode(to: &byteBuffer)
        }
        if let deviceAndSensorStatus {
            deviceAndSensorStatus.encode(to: &byteBuffer)
        }
        if let pulseAmplitudeIndex {
            pulseAmplitudeIndex.encode(to: &byteBuffer)
        }
    }
}
