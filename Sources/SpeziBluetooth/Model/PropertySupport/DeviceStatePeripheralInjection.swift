//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


@SpeziBluetooth
class DeviceStatePeripheralInjection<Value: Sendable>: Sendable {
    private let bluetooth: Bluetooth
    let peripheral: BluetoothPeripheral
    private let accessKeyPath: DeviceState<Value>.KeyPathType
    private let observationKeyPath: KeyPath<PeripheralStorage, Value>?
    private let subscriptions: ChangeSubscriptions<Value>

    nonisolated var value: Value {
        peripheral[keyPath: accessKeyPath]
    }


    init(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, keyPath: DeviceState<Value>.KeyPathType) {
        self.bluetooth = bluetooth
        self.peripheral = peripheral
        self.accessKeyPath = keyPath
        self.observationKeyPath = keyPath.storageEquivalent()
        self.subscriptions = ChangeSubscriptions()
    }

    func setup() {
        trackStateUpdate()
    }

    private func trackStateUpdate() {
        guard let observationKeyPath else {
            return
        }

        peripheral.onChange(of: observationKeyPath) { [weak self] value in
            guard let self = self else {
                return
            }

            self.trackStateUpdate()
            self.subscriptions.notifySubscribers(with: value)
        }
    }

    nonisolated func newSubscription() -> AsyncStream<Value> {
        subscriptions.newSubscription()
    }

    nonisolated func newOnChangeSubscription(
        initial: Bool,
        perform action: @escaping @Sendable (_ oldValue: Value, _ newValue: Value) async -> Void
    ) {
        let id = subscriptions.newOnChangeSubscription(perform: action)

        if initial {
            let value = peripheral[keyPath: accessKeyPath]
            Task { @SpeziBluetooth in
                subscriptions.notifySubscriber(id: id, with: value)
            }
        }
    }

    deinit {
        bluetooth.notifyDeviceDeinit(for: peripheral.id)
    }
}


extension KeyPath where Root == BluetoothPeripheral {
    @SpeziBluetooth
    func storageEquivalent() -> KeyPath<PeripheralStorage, Value>? {
        let anyKeyPath: AnyKeyPath? = switch self {
        case \.name:
            \PeripheralStorage.name
        case \.rssi:
            \PeripheralStorage.rssi
        case \.advertisementData:
            \PeripheralStorage.advertisementData
        case \.state:
            \PeripheralStorage.state
        case \.nearby:
            \PeripheralStorage.nearby
        case \.lastActivity:
            \PeripheralStorage.lastActivity
        case \.id:
            nil
        default:
            preconditionFailure("Could not find a observable translation for peripheral KeyPath \(self)")
        }

        guard let anyKeyPath else {
            return nil
        }

        guard let keyPath = anyKeyPath as? KeyPath<PeripheralStorage, Value> else {
            preconditionFailure("Failed to cast KeyPath \(anyKeyPath) to \(KeyPath<PeripheralStorage, Value>.self)")
        }

        return keyPath
    }
}
