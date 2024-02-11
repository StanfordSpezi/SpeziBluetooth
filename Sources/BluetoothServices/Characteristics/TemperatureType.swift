//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO
import SpeziBluetooth


/// The location of a temperature measurement.
public enum TemperatureType: UInt8, CaseIterable {
    /// Reserved for future use.
    case reserved
    /// Armpit.
    case armpit
    /// Body (general).
    case body
    /// Ear (usually earlobe).
    case ear
    /// Finger.
    case finger
    /// Gastrointestinal Tract.
    case gastrointestinalTract
    /// Mouth.
    case mouth
    /// Rectum.
    case rectum
    /// Toe.
    case toe
    /// Tympanum (ear drum).
    case tympanum
}


extension TemperatureType: Equatable {}


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
