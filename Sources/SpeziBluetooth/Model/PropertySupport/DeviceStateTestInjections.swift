//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class DeviceStateTestInjections<Value: Sendable>: Sendable {
    private nonisolated(unsafe) var _subscriptions: ChangeSubscriptions<Value>?
    private nonisolated(unsafe) var _injectedValue: Value?
    private let lock = NSLock() // protects both properties above

    var subscriptions: ChangeSubscriptions<Value>? {
        get {
            lock.withLock {
                _subscriptions
            }
        }
        set {
            lock.withLock {
                _subscriptions = newValue
            }
        }
    }

    var injectedValue: Value? {
        get {
            lock.withLock {
                _injectedValue
            }
        }
        set {
            lock.withLock {
                _injectedValue = newValue
            }
        }
    }

    static func artificialValue(for keyPath: KeyPath<BluetoothPeripheral, Value>) -> Value? {
        let value: Any? = switch keyPath {
        case \.id:
            nil // we cannot provide a stable id?
        case \.name:
            Optional<String>.none as Any
        case \.state:
            PeripheralState.disconnected
        case \.advertisementData:
            AdvertisementData([:])
        case \.rssi:
            Int(UInt8.max)
        case \.nearby:
            false
        case \.lastActivity:
            Date.now
        default:
            nil
        }

        guard let value else {
            return nil
        }

        guard let value = value as? Value else {
            preconditionFailure("Default value \(value) was not the expected type for \(keyPath)")
        }
        return value
    }

    func enableSubscriptions() {
        subscriptions = ChangeSubscriptions<Value>()
    }
}
