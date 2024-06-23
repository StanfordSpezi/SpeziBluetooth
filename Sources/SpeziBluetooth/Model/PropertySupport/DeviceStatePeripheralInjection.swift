//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


actor DeviceStatePeripheralInjection<Value>: BluetoothActor {
    let bluetoothQueue: DispatchSerialQueue

    private let bluetooth: Bluetooth
    private let peripheral: BluetoothPeripheral
    private let accessKeyPath: KeyPath<BluetoothPeripheral, Value>
    private let observationKeyPath: KeyPath<PeripheralStorage, Value>?
    private let subscriptions = ChangeSubscriptions<Value>()

    nonisolated var value: Value {
        peripheral[keyPath: accessKeyPath]
    }


    init(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, keyPath: KeyPath<BluetoothPeripheral, Value>) {
        self.bluetooth = bluetooth
        self.bluetoothQueue = peripheral.bluetoothQueue
        self.peripheral = peripheral
        self.accessKeyPath = keyPath
        self.observationKeyPath = keyPath.storageEquivalent()
    }

    func setup() {
        trackStateUpdate()
    }

    private func trackStateUpdate() {
        guard let observationKeyPath else {
            return
        }

        peripheral.assumeIsolated { peripheral in
            peripheral.onChange(of: observationKeyPath) { [weak self] value in
                guard let self = self else {
                    return
                }

                self.assumeIsolated { injection in
                    injection.trackStateUpdate()

                    self.subscriptions.notifySubscribers(with: value)
                }
            }
        }
    }

    nonisolated func newSubscription() -> AsyncStream<Value> {
        subscriptions.newSubscription()
    }

    nonisolated func newOnChangeSubscription(initial: Bool, perform action: @escaping (Value) async -> Void) {
        subscriptions.newOnChangeSubscription(perform: action)

        if initial {
            let value = peripheral[keyPath: accessKeyPath]
            Task { @SpeziBluetooth in
                await self.isolated { _ in
                    await action(value)
                }
            }
        }
    }

    deinit {
        bluetooth.notifyDeviceDeinit(for: peripheral.id)
    }
}


extension KeyPath where Root == BluetoothPeripheral {
    // swiftlint:disable:next cyclomatic_complexity
    func storageEquivalent() -> KeyPath<PeripheralStorage, Value>? {
        let anyKeyPath: AnyKeyPath? = switch self {
        case \.name:
            \PeripheralStorage.name
        case \.localName:
            \PeripheralStorage.localName
        case \.rssi:
            \PeripheralStorage.rssi
        case \.advertisementData:
            \PeripheralStorage.advertisementData
        case \.state:
            \PeripheralStorage.state
        case \.services:
            \PeripheralStorage.services
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
