//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import NIO
import SpeziBluetooth

// TODO: what do we wanna test
//  - ready only characteristic?
//  - (write-only characteristics?)
//  - read-write characteristics?
//  - notify characteristics (+ auto-subscribe)


@_spi(TestingSupport)
extension CBUUID {
    private static func uuid(ofCustom: String) -> CBUUID {
        precondition(ofCustom.count == 4, "Unexpected length of \(ofCustom.count)")
        return CBUUID(string: "0000\(ofCustom)-0000-1000-8000-00805F9B34FB")
    }

    public static let testService: CBUUID = .uuid(ofCustom: "F001")

    public static let testCharacteristic: CBUUID = .uuid(ofCustom: "F002")
    public static let eventLogCharacteristic: CBUUID = .uuid(ofCustom: "F003")
}


@_spi(TestingSupport)
public enum EventLog {
    case subscribedToNotification(_ characteristic: CBUUID)
    case unsubscribedToNotification(_ characteristic: CBUUID)
    case receivedRead(_ characteristic: CBUUID)
    case receivedWrite(_ characteristic: CBUUID, value: Data)
}


@_spi(TestingSupport)
extension EventLog: ByteCodable {
    private enum EventType: UInt8 {
        case subscribed
        case unsubscribed
        case read
        case write
    }

    private var type: EventType {
        switch self {
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

    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt8(from: &byteBuffer),
              let type = EventType(rawValue: rawValue) else {
            return nil
        }

        guard let data = byteBuffer.readData(length: 16) else { // 128-bit UUID
            return nil
        }

        let characteristic = CBUUID(data: data)


        switch type {
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

    public func encode(to byteBuffer: inout ByteBuffer) {
        type.rawValue.encode(to: &byteBuffer)
        switch self {
        case let .subscribedToNotification(characteristic):
            characteristic.data.encode(to: &byteBuffer)
        case let .unsubscribedToNotification(characteristic):
            characteristic.data.encode(to: &byteBuffer)
        case let .receivedRead(characteristic):
            characteristic.data.encode(to: &byteBuffer)
        case let .receivedWrite(characteristic, value):
            characteristic.data.encode(to: &byteBuffer)
            byteBuffer.writeData(value)
        }
    }
}


@_spi(TestingSupport)
public class TestService: BluetoothService {
    public static let id: CBUUID = .testService

    @Characteristic(id: .testCharacteristic)
    public var test: String?

    @Characteristic(id: .eventLogCharacteristic, notify: true)
    public var eventLog: EventLog?
}
