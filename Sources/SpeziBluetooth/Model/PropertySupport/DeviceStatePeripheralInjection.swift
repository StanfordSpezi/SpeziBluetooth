//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation

enum ChangeClosure<Value> { // TODO: to be used by @Characteristic, move somewhere?
    case none
    case value(_ closure: (Value) async -> Void)
    case cleared
}


actor DeviceStatePeripheralInjection<Value>: BluetoothActor {
    let bluetoothQueue: DispatchSerialQueue

    let peripheral: BluetoothPeripheral
    private let keyPath: KeyPath<PeripheralStorage, Value> // TODO: the actor thingy broke this!
    private var onChangeClosure: ChangeClosure<Value>


    init(peripheral: BluetoothPeripheral, keyPath: KeyPath<BluetoothPeripheral, Value>, onChangeClosure: ((Value) async -> Void)?) {
        self.bluetoothQueue = peripheral.bluetoothQueue
        self.peripheral = peripheral
        self.keyPath = keyPath.transform()
        self.onChangeClosure = onChangeClosure.map { .value($0) } ?? .none
    }

    func setup() {
        trackStateUpdate()
    }

    private func trackStateUpdate() {
        peripheral.assumeIsolated { peripheral in
            peripheral.onChange(of: keyPath) { [weak self] value in
                guard let self = self else {
                    return
                }

                self.assumeIsolated { injection in
                    injection.trackStateUpdate()
                    Task { @SpeziBluetooth in
                        await injection.dispatchChangeHandler(value)
                    }
                }
            }
        }
    }

    /// Returns once the change handler completes.
    private func dispatchChangeHandler(_ value: Value) async {
        guard case let .value(closure) = onChangeClosure else {
            return
        }

        await closure(value) // TODO: does this stay sync???
    }

    func setOnChangeClosure(_ closure: @escaping (Value) async -> Void) {
        if case .cleared = onChangeClosure {
            // object is about to be cleared. Make sure we don't create a self reference last minute.
            return
        }

        self.onChangeClosure = .value(closure)
    }

    /// Remove any onChangeClosure and mark injection as cleared.
    ///
    /// This important to ensure to clear any potential reference cycles because of a captured self in the closure.
    func clearOnChangeClosure() {
        onChangeClosure = .cleared
    }
}


extension KeyPath where Root == BluetoothPeripheral {
    func transform() -> KeyPath<PeripheralStorage, Value> {
        let anyKeyPath: AnyKeyPath = switch self {
        case \.name:
            \PeripheralStorage.name
        case \.rssi:
            \PeripheralStorage.rssi
        case \.advertisementData:
            \PeripheralStorage.advertisementData
        case \.state:
            \PeripheralStorage.state
        case \.services:
            \PeripheralStorage.services
        default:
            preconditionFailure("Could not find a translation for peripheral KeyPath \(self)")
        }

        guard let keyPath = anyKeyPath as? KeyPath<PeripheralStorage, Value> else {
            preconditionFailure("Failed to cast KeyPath \(anyKeyPath) to \(KeyPath<PeripheralStorage, Value>.self)")
        }

        return keyPath
    }
}
