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


/// Features of a weight scale.
///
/// Refer to GATT Specification Supplement, 3.253 Weight Scale Feature.
public struct WeightScaleFeature: OptionSet {
    /// Weight resolutions for a weight measurement.
    public struct WeightResolution: RawRepresentable {
        /// Unspecified resolution, falling back to the default.
        public static let unspecified = WeightResolution(forceRawValue: 0)
        /// Resolution of 0.5 kg or 1 lb.
        public static let resolution500g = WeightResolution(forceRawValue: 1)
        /// Resolution 0.2 kg or 0.5 lb.
        public static let resolution200g = WeightResolution(forceRawValue: 2)
        /// Resolution 0.1 kg or 0.2 lb.
        public static let resolution100g = WeightResolution(forceRawValue: 3)
        /// Resolution 0.05 kg or 0.1 lb.
        public static let resolution50g = WeightResolution(forceRawValue: 4)
        /// Resolution 0.02 kg or 0.05 lb.
        public static let resolution20g = WeightResolution(forceRawValue: 5)
        /// Resolution 0.01 kg or 0.02 lb.
        public static let resolution10g = WeightResolution(forceRawValue: 6)
        /// Resolution 0.005 kg or 0.01 lb.
        public static let resolution5g = WeightResolution(forceRawValue: 7)

        public let rawValue: UInt8

        public init?(rawValue: UInt8) {
            guard rawValue <= 0b1111 else {
                return nil
            }
            self.rawValue = rawValue
        }

        private init(forceRawValue rawValue: UInt8) {
            precondition(rawValue <= 0b1111, "Value out of range: \(rawValue)")
            self.rawValue = rawValue
        }


        func magnitude(in unit: WeightMeasurement.Unit) -> Double { // swiftlint:disable:this cyclomatic_complexity function_body_length
            switch self {
            case .resolution500g:
                switch unit {
                case .si:
                    0.5
                case .imperial:
                    1
                }
            case .resolution200g:
                switch unit {
                case .si:
                    0.2
                case .imperial:
                    0.5
                }
            case .resolution100g:
                switch unit {
                case .si:
                    0.1
                case .imperial:
                    0.2
                }
            case .resolution50g:
                switch unit {
                case .si:
                    0.05
                case .imperial:
                    0.1
                }
            case .resolution20g:
                switch unit {
                case .si:
                    0.02
                case .imperial:
                    0.05
                }
            case .resolution10g:
                switch unit {
                case .si:
                    0.01
                case .imperial:
                    0.02
                }
            case .unspecified, .resolution5g:
                switch unit {
                case .si:
                    0.005
                case .imperial:
                    0.01
                }
            default:
                switch unit {
                case .si:
                    0.005
                case .imperial:
                    0.01
                }
            }
        }
    }


    public struct HeightResolution: RawRepresentable {
        /// Unspecified resolution, falling back to the default.
        public static let unspecified = HeightResolution(forceRawValue: 0)
        /// Resolution of 0.01 meter or 1 inch.
        public static let resolution10mm = HeightResolution(forceRawValue: 1)
        /// Resolution of 0.005 meter or 0.5 inch.
        public static let resolution5mm = HeightResolution(forceRawValue: 2)
        /// Resolution of 0.001 meter or 0.1 inch.
        public static let resolution1mm = HeightResolution(forceRawValue: 3)

        public let rawValue: UInt8

        public init?(rawValue: UInt8) {
            guard rawValue <= 0b111 else {
                return nil
            }
            self.rawValue = rawValue
        }

        private init(forceRawValue rawValue: UInt8) {
            precondition(rawValue <= 0b111, "Value out of range: \(rawValue)")
            self.rawValue = rawValue
        }

        func magnitude(in unit: WeightMeasurement.Unit) -> Double { // swiftlint:disable:this cyclomatic_complexity
            switch self {
            case .resolution10mm:
                switch unit {
                case .si:
                    0.01
                case .imperial:
                    1
                }
            case .resolution5mm:
                switch unit {
                case .si:
                    0.005
                case .imperial:
                    0.5
                }
            case .unspecified, .resolution1mm:
                switch unit {
                case .si:
                    0.001
                case .imperial:
                    0.1
                }
            default:
                switch unit {
                case .si:
                    0.001
                case .imperial:
                    0.01
                }
            }
        }
    }

    public static let timeStampSupported = WeightScaleFeature(rawValue: 1 << 0)
    public static let multipleUsersSupported = WeightScaleFeature(rawValue: 1 << 1)
    public static let bmiSupported = WeightScaleFeature(rawValue: 1 << 2)

    public let rawValue: UInt32

    public var weightResolution: WeightResolution {
        let rawValue = UInt8((rawValue >> 3) & 0b1111)
        return WeightResolution(rawValue: rawValue) ?? .unspecified
    }

    public var heightResolution: HeightResolution {
        let rawValue = UInt8((rawValue >> 7) & 0b111)
        return HeightResolution(rawValue: rawValue) ?? .unspecified
    }


    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Create new weight scale features.
    /// - Parameters:
    ///   - weightResolution: The resolution for weight values for a ``WeightMeasurement``.
    ///   - heightResolution: The resolution for height values for a ``WeightMeasurement``.
    ///   - options: Additional flags and options of ``WeightScaleFeature`` (e.g., BMI support or multi user support).
    public init(weightResolution: WeightResolution, heightResolution: HeightResolution = .unspecified, options: WeightScaleFeature...) {
        let rawValue = (UInt32(weightResolution.rawValue) << 3) | (UInt32(heightResolution.rawValue) << 7)
        self = WeightScaleFeature(rawValue: rawValue).union(WeightScaleFeature(options))
    }
}


extension WeightScaleFeature.WeightResolution: Hashable, Sendable {}


extension WeightScaleFeature.HeightResolution: Hashable, Sendable {}


extension WeightScaleFeature: Hashable, Sendable {}


extension WeightScaleFeature: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt32(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
