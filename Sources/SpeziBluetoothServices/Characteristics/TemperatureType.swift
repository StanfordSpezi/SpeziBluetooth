//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIO


/// The location of a temperature measurement.
///
/// Refer to GATT Specification Supplement, 3.219 Temperature Type.
public struct TemperatureType {
    /// Reserved for future use.
    public static let reserved = TemperatureType(rawValue: 0x00)
    /// Armpit.
    public static let armpit = TemperatureType(rawValue: 0x01)
    /// Body (general).
    public static let body = TemperatureType(rawValue: 0x02)
    /// Ear (usually earlobe).
    public static let ear = TemperatureType(rawValue: 0x03)
    /// Finger.
    public static let finger = TemperatureType(rawValue: 0x04)
    /// Gastrointestinal Tract.
    public static let gastrointestinalTract = TemperatureType(rawValue: 0x05)
    /// Mouth.
    public static let mouth = TemperatureType(rawValue: 0x06)
    /// Rectum.
    public static let rectum = TemperatureType(rawValue: 0x07)
    /// Toe.
    public static let toe = TemperatureType(rawValue: 0x08)
    /// Tympanum (ear drum).
    public static let tympanum = TemperatureType(rawValue: 0x09)

    /// The raw value.
    public let rawValue: UInt8

    /// Create temperature type from raw value.
    /// - Parameter rawValue: The raw value temperature type.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}


extension TemperatureType: RawRepresentable {}


extension TemperatureType: Hashable, Sendable {}


extension TemperatureType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .reserved:
            "reserved"
        case .armpit:
            "armpit"
        case .body:
            "body"
        case .ear:
            "ear"
        case .finger:
            "finger"
        case .gastrointestinalTract:
            "gastrointestinalTract"
        case .mouth:
            "mouth"
        case .rectum:
            "rectum"
        case .toe:
            "toe"
        case .tympanum:
            "tympanum"
        default:
            "\(Self.self)(rawValue: \(rawValue))"
        }
    }
}


extension TemperatureType: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let value = UInt8(from: &byteBuffer) else {
            return nil
        }

        self.init(rawValue: value)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension TemperatureType: Codable {}
