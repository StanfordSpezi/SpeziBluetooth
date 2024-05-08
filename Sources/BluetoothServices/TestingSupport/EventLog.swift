//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
@preconcurrency import CoreBluetooth
import NIO
@_spi(TestingSupport)
import SpeziBluetooth


/// An event emitted by the test peripheral.
///
/// Those events always imply to happen on characteristics of the `TestService`.
@_spi(TestingSupport)
public enum EventLog {
    /// No event happened yet.
    case none
    /// Central subscribed to the notifications of the given characteristic.
    case subscribedToNotification(_ characteristic: CBUUID)
    /// Central unsubscribed to the notifications of the given characteristic.
    case unsubscribedToNotification(_ characteristic: CBUUID)
    /// The peripheral received a read request for the given characteristic.
    case receivedRead(_ characteristic: CBUUID)
    /// The peripheral received a write request for the given characteristic and data.
    case receivedWrite(_ characteristic: CBUUID, value: Data)
}


@_spi(TestingSupport)
extension EventLog: Hashable, Sendable {}


@_spi(TestingSupport)
extension EventLog: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            "none"
        case let .subscribedToNotification(characteristic):
            "Subscribed to notifications for \(characteristic)"
        case let .unsubscribedToNotification(characteristic):
            "Unsubscribed from notifications for \(characteristic)"
        case let .receivedRead(characteristic):
            "Received read request for \(characteristic)"
        case let .receivedWrite(characteristic, value):
            "Received write request for \(characteristic): \(value.hexString())"
        }
    }
}


@_spi(TestingSupport)
extension EventLog: ByteCodable {
    private enum EventType: UInt8 {
        case none
        case subscribed
        case unsubscribed
        case read
        case write
    }

    private var type: EventType {
        switch self {
        case .none:
            return .none
        case .subscribedToNotification:
            return .subscribed
        case .unsubscribedToNotification:
            return .unsubscribed
        case .receivedRead:
            return .read
        case .receivedWrite:
            return .write
        }
    }

    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt8(from: &byteBuffer, preferredEndianness: endianness),
              let type = EventType(rawValue: rawValue) else {
            return nil
        }

        if case type = .none {
            // non has no characteristic to read, so skip here. Makes it easier below.
            self = .none
            return
        }

        guard let data = byteBuffer.readData(length: 16) else { // 128-bit UUID
            return nil
        }

        let characteristic = CBUUID(data: data)


        switch type {
        case .none:
            self = .none
        case .subscribed:
            self = .subscribedToNotification(characteristic)
        case .unsubscribed:
            self = .unsubscribedToNotification(characteristic)
        case .read:
            self = .receivedRead(characteristic)
        case .write:
            guard let value = byteBuffer.readData(length: byteBuffer.readableBytes) else {
                return nil
            }
            self = .receivedWrite(characteristic, value: value)
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        type.rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
        switch self {
        case .none:
            break
        case let .subscribedToNotification(characteristic):
            characteristic.data.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .unsubscribedToNotification(characteristic):
            characteristic.data.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .receivedRead(characteristic):
            characteristic.data.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .receivedWrite(characteristic, value):
            characteristic.data.encode(to: &byteBuffer, preferredEndianness: endianness)
            byteBuffer.writeData(value)
        }
    }
}
