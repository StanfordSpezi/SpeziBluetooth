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


/// The features supported by a Bluetooth-enabled Pulse Oximeter.
public struct PLXFeatures: ByteCodable, Hashable, Sendable, Codable {
    /// The measurement-status-fields supported by this device.
    /// - Note: Even though this is the same type as ``PLXContinuousMeasurement.MeasurementStatus``
    ///     used for continuous measurements, in the ``PLXFeatures``-context, the fields here are interpreted as indicating
    ///     whether the device supports the field, and not whether the field's described thing is currently true.
    ///     E.g.: `MeasurementStatus.measurementIsOngoing` being present on `PLXFeatures.measurementStatusSupport`
    ///     only means that the device can report, when taking a measurement, whether the measurement is still ongoing.
    ///     It does not mean that there is a measurement ongoing right now.
    public typealias MeasurementStatusSupport = PLXContinuousMeasurement.MeasurementStatus
    /// The device- and sensor-status-fields supported by this device.
    /// - Note: Even though this is the same type as ``PLXContinuousMeasurement.DeviceAndSensorStatus``
    ///     used for continuous measurements, in the ``PLXFeatures``-context, the fields here are interpreted as indicating
    ///     whether the device supports the field, and not whether the field's described thing is currently true.
    ///     E.g.: `DeviceAndSensorStatus.erraticSignalDetected` being present on `PLXFeatures.deviceAndSensorStatusSupport`
    ///     only means that the device can report, when taking a measurement, whether an erratic signal was detected.
    ///     It does not mean that there is an erratic signal right now.
    public typealias DeviceAndSensorStatusSupport = PLXContinuousMeasurement.DeviceAndSensorStatus
    
    /// The features supported by the device.
    public struct SupportedFeatures: OptionSet, ByteCodable, Hashable, Sendable, Codable {
        public let rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
        
        public init?(from byteBuffer: inout ByteBuffer) {
            guard let rawValue = byteBuffer.readInteger(endianness: .little, as: RawValue.self) else {
                return nil
            }
            self.init(rawValue: rawValue)
        }
        
        public func encode(to byteBuffer: inout ByteBuffer) {
            byteBuffer.writeInteger(rawValue, endianness: .little)
        }
        
        public static let hasMeasurementStatusSupport = Self(rawValue: 1 << 0)
        public static let hasDeviceAndSensorStatusSupport = Self(rawValue: 1 << 1)
        public static let hasSpotCheckMeasurementsStorage = Self(rawValue: 1 << 2)
        public static let hasSpotCheckTimestampSupport = Self(rawValue: 1 << 3)
        public static let hasSpO2PRFastSupport = Self(rawValue: 1 << 4)
        public static let hasSpO2PRSlowSupport = Self(rawValue: 1 << 5)
        public static let hasPulseAmplitudeIndexSupport = Self(rawValue: 1 << 6)
        public static let supportsMultipleBonds = Self(rawValue: 1 << 7)
    }
    
    
    public let supportedFeatures: SupportedFeatures
    public let measurementStatusSupport: MeasurementStatusSupport?
    public let deviceAndSensorStatusSupport: DeviceAndSensorStatusSupport?
    
    internal init(
        supportedFeatures: SupportedFeatures,
        measurementStatusSupport: MeasurementStatusSupport?,
        deviceAndSensorStatusSupport: DeviceAndSensorStatusSupport?
    ) {
        if supportedFeatures.contains(.hasMeasurementStatusSupport) && measurementStatusSupport == nil {
            preconditionFailure(".hasMeasurementStatusSupport flag specified in features, but measurementStatusSupport parameter is nil")
        }
        if supportedFeatures.contains(.hasDeviceAndSensorStatusSupport) && deviceAndSensorStatusSupport == nil {
            preconditionFailure(".hasDeviceAndSensorStatusSupport flag specified in features, but deviceAndSensorStatusSupport parameter is nil")
        }
        self.supportedFeatures = supportedFeatures
        self.measurementStatusSupport = measurementStatusSupport
        self.deviceAndSensorStatusSupport = deviceAndSensorStatusSupport
    }
    
    
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let supportedFeatures = SupportedFeatures(from: &byteBuffer) else {
            return nil
        }
        self.supportedFeatures = supportedFeatures
        if supportedFeatures.contains(.hasMeasurementStatusSupport) {
            guard let support = MeasurementStatusSupport(from: &byteBuffer) else {
                return nil
            }
            self.measurementStatusSupport = support
        } else {
            self.measurementStatusSupport = nil
        }
        if supportedFeatures.contains(.hasDeviceAndSensorStatusSupport) {
            guard let support = DeviceAndSensorStatusSupport(from: &byteBuffer) else {
                return nil
            }
            self.deviceAndSensorStatusSupport = support
        } else {
            self.deviceAndSensorStatusSupport = nil
        }
    }
    
    
    public func encode(to byteBuffer: inout ByteBuffer) {
        supportedFeatures.encode(to: &byteBuffer)
        if let measurementStatusSupport {
            measurementStatusSupport.encode(to: &byteBuffer)
        }
        if let deviceAndSensorStatusSupport {
            deviceAndSensorStatusSupport.encode(to: &byteBuffer)
        }
    }
}
