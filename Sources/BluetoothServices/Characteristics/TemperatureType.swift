//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO
import SpeziBluetooth


public enum TemperatureType: UInt8 {
    case reserved
    case armpit
    case body // TODO: general
    case ear
    case finger
    case gastrointestinalTract
    case mouth
    case rectum
    case toe
    case tympanum
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
