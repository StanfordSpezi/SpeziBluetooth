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

    let peripheral: BluetoothPeripheral
    private let accessKeyPath: KeyPath<BluetoothPeripheral, Value>
    private let observationKeyPath: KeyPath<PeripheralStorage, Value>?
    private var onChangeClosure: ChangeClosureState<Value>


    init(peripheral: BluetoothPeripheral, keyPath: KeyPath<BluetoothPeripheral, Value>, onChangeClosure: OnChangeClosure<Value>?) {
        self.bluetoothQueue = peripheral.bluetoothQueue
        self.peripheral = peripheral
        self.accessKeyPath = keyPath
        self.observationKeyPath = keyPath.storageEquivalent()
        self.onChangeClosure = onChangeClosure.map { .value($0) } ?? .none
    }

    func setup() {
        trackStateUpdate()
    }

    private func trackStateUpdate() {
        guard let observationKeyPath else {
            return
        }

        dispatchOnChangeWithInitialValue()

        peripheral.assumeIsolated { peripheral in
            peripheral.onChange(of: observationKeyPath) { [weak self] value in
                guard let self = self else {
                    return
                }

                self.assumeIsolated { injection in
                    injection.trackStateUpdate()

                    // The onChange handler of global Bluetooth module is called right after this to clear this
                    // injection if the state changed to `disconnected`. So we must capture the onChangeClosure before
                    // that to still be able to deliver `disconnected` events.
                    let onChangeClosure = injection.onChangeClosure
                    Task { @SpeziBluetooth in
                        await injection.dispatchChangeHandler(value, with: onChangeClosure)
                    }
                }
            }
        }
    }

    /// Returns once the change handler completes.
    private func dispatchChangeHandler(_ value: Value, with onChangeClosure: ChangeClosureState<Value>, isInitial: Bool = false) async {
        guard case let .value(closure) = onChangeClosure else {
            return
        }

        if closure.initial || !isInitial {
            await closure(value)
        }
    }

    func setOnChangeClosure(_ closure: OnChangeClosure<Value>) {
        if case .cleared = onChangeClosure {
            // object is about to be cleared. Make sure we don't create a self reference last minute.
            return
        }

        self.onChangeClosure = .value(closure)
        dispatchOnChangeWithInitialValue()
    }

    private func dispatchOnChangeWithInitialValue() {
        // For most values, this just delivers a nil value (e.g., name or localName).
        // However, there might be a use case to retrieve the initial value for the deviceState or advertisement data.
        let value = peripheral[keyPath: accessKeyPath]
        Task { @SpeziBluetooth in
            await dispatchChangeHandler(value, with: onChangeClosure, isInitial: true)
        }
    }

    /// Remove any onChangeClosure and mark injection as cleared.
    ///
    /// This important to ensure to clear any potential reference cycles because of a captured self in the closure.
    func clearOnChangeClosure() {
        onChangeClosure = .cleared
    }
}


extension KeyPath where Root == BluetoothPeripheral {
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
        case \.services:
            \PeripheralStorage.services
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
