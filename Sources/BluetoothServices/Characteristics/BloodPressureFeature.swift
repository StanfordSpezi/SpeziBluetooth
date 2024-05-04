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

    // TODO: docs

    public static let bodyMovementDetectionSupported = BloodPressureFeature(rawValue: 1 << 0)
    public static let cuffFitDetectionSupported = BloodPressureFeature(rawValue: 1 << 1)
    public static let irregularPulseDetectionSupported = BloodPressureFeature(rawValue: 1 << 2)
    public static let pulseRateRangeDetectionSupported = BloodPressureFeature(rawValue: 1 << 3)
    public static let measurementPositionDetectionSupported = BloodPressureFeature(rawValue: 1 << 4)
    public static let multipleBondsSupported = BloodPressureFeature(rawValue: 1 << 5)
    public static let e2eCrcSupported = BloodPressureFeature(rawValue: 1 << 6)
    public static let userDataServiceSupported = BloodPressureFeature(rawValue: 1 << 7)
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
