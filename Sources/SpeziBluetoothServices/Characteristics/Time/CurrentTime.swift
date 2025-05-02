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


/// The current time and a reason for adjustment.
///
/// Refer to GATT Specification Supplement, 3.62 Current Time.
public struct CurrentTime {
    /// The reason why a peripheral adjusted its current time.
    public struct AdjustReason: OptionSet {
        /// The time information on the device was manually set or changed.
        ///
        /// - Note: Also set this flag if the time zone or DST offset were changed manually.
        public static let manualTimeUpdate = AdjustReason(rawValue: 1 << 0)
        /// Received time information from an external time reference source.
        public static let externalReferenceTimeUpdate = AdjustReason(rawValue: 1 << 1)
        /// The time information was changed due to a change of time zone.
        public static let changeOfTimeZone = AdjustReason(rawValue: 1 << 2)
        /// The time information was changed due to a change of Daylight Savings Time (DST).
        public static let changeOfDST = AdjustReason(rawValue: 1 << 3)

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// The current time.
    public let time: ExactTime256
    /// The reason for adjusting time.
    public let adjustReason: AdjustReason


    /// Initialize a new current time.
    /// - Parameters:
    ///   - time: The current, exact time.
    ///   - adjustReason: The peripheral reported reason for adjusting time.
    public init(time: ExactTime256, adjustReason: AdjustReason = []) {
        self.time = time
        self.adjustReason = adjustReason
    }
}


extension CurrentTime.AdjustReason: Hashable, Sendable {}


extension CurrentTime.AdjustReason: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        var components: [String] = []
        if contains(.manualTimeUpdate) {
            components.append("manualTimeUpdate")
        }
        if contains(.externalReferenceTimeUpdate) {
            components.append("externalReferenceTimeUpdate")
        }
        if contains(.changeOfTimeZone) {
            components.append("changeOfTimeZone")
        }
        if contains(.changeOfDST) {
            components.append("changeOfDST")
        }
        return "[\(components.joined(separator: ", "))]"
    }

    public var debugDescription: String {
        "\(Self.self)(rawValue: 0x\(String(format: "%02X", rawValue)))"
    }
}


extension CurrentTime: Hashable, Sendable {}


extension CurrentTime.AdjustReason: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt8(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension CurrentTime: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let time = ExactTime256(from: &byteBuffer),
              let adjustReason = AdjustReason(from: &byteBuffer) else {
            return nil
        }

        self.init(time: time, adjustReason: adjustReason)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        time.encode(to: &byteBuffer)
        adjustReason.encode(to: &byteBuffer)
    }
}


extension CurrentTime.AdjustReason: Codable {}


extension CurrentTime: Codable {}
