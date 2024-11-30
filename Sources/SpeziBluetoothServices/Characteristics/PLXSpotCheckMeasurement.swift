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


/// A PLX Spot-check Measurement, as defined in the [Bluetooth specification](https://www.bluetooth.com/specifications/specs/plxs-html/).
public struct PLXSpotCheckMeasurement: ByteCodable, Hashable, Sendable, Codable {
    public typealias MeasurementStatus = PLXContinuousMeasurement.MeasurementStatus
    public typealias DeviceAndSensorStatus = PLXContinuousMeasurement.DeviceAndSensorStatus
    
    struct Flags: OptionSet, ByteCodable, Hashable, Codable {
        let rawValue: UInt8
        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        static let hasTimestamp = Self(rawValue: 1 << 0)
        static let hasMeasurementStatus = Self(rawValue: 1 << 1)
        static let hasDeviceAndSensorStatus = Self(rawValue: 1 << 2)
        static let hasPulseAmplitudeIndex = Self(rawValue: 1 << 3)
        static let deviceClockIsNotSet = Self(rawValue: 1 << 4)
    }
    
    /// The measured blood oxygen saturation
    /// Unit: percentage, with a resolution of 1.
    public let oxygenSaturation: MedFloat16
    /// The measured heart rate, in beats per minute.
    public let pulseRate: MedFloat16
    /// The specific time and date the measurement was recorded.
    public let timestamp: DateTime?
    /// Additional information about the measurement, if applicable.
    public let measurementStatus: MeasurementStatus?
    /// Device status flags.
    public let deviceAndSensorStatus: DeviceAndSensorStatus?
    /// Percentage indicating a user's perfusion level (amount of blood being delivered to the capillary bed).
    public let pulseAmplitudeIndex: MedFloat16?
    
    /// Creates a new ``PLXSpotCheckMeasurement`` with the specified values.
    public init(
        oxygenSaturation: MedFloat16,
        pulseRate: MedFloat16,
        timestamp: DateTime? = nil,
        measurementStatus: MeasurementStatus? = nil,
        deviceAndSensorStatus: DeviceAndSensorStatus? = nil,
        pulseAmplitudeIndex: MedFloat16? = nil
    ) {
        self.oxygenSaturation = oxygenSaturation
        self.pulseRate = pulseRate
        self.timestamp = timestamp
        self.measurementStatus = measurementStatus
        self.deviceAndSensorStatus = deviceAndSensorStatus
        self.pulseAmplitudeIndex = pulseAmplitudeIndex
    }
    
    
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let flags = Flags(from: &byteBuffer) else {
            return nil
        }
        if let oxygen = MedFloat16(from: &byteBuffer),
           let pulseRate = MedFloat16(from: &byteBuffer) {
            self.oxygenSaturation = oxygen
            self.pulseRate = pulseRate
        } else {
            return nil
        }
        if flags.contains(.hasTimestamp) {
            guard let timestamp = DateTime(from: &byteBuffer) else {
                return nil
            }
            self.timestamp = timestamp
        } else {
            self.timestamp = nil
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
            if timestamp != nil {
                flags.insert(.hasTimestamp)
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
        if let timestamp {
            timestamp.encode(to: &byteBuffer)
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
