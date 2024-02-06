//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation

enum ChangeClosure<Value> { // TODO: to be used by @Characteristic, move somewhere?
    case none
    case value(_ closure: (Value) async -> Void)
    case cleared
}


actor DeviceStatePeripheralInjection<Value> {
    private let bluetoothExecutor: BluetoothSerialExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        bluetoothExecutor.asUnownedSerialExecutor()
    }

    let peripheral: BluetoothPeripheral
    private let keyPath: KeyPath<BluetoothPeripheral, Value>
    private var onChangeClosure: ChangeClosure<Value>


    init(peripheral: BluetoothPeripheral, keyPath: KeyPath<BluetoothPeripheral, Value>, onChangeClosure: ((Value) async -> Void)?) {
        self.bluetoothExecutor = BluetoothSerialExecutor(copy: peripheral.bluetoothExecutor)
        self.peripheral = peripheral
        self.keyPath = keyPath
        self.onChangeClosure = onChangeClosure.map { .value($0) } ?? .none
    }

    func setup() {
        trackStateUpdate()
    }

    private func trackStateUpdate() {
        withObservationTracking {
            _ = peripheral[keyPath: keyPath]
        } onChange: { [weak self] in
            Task { [weak self] in
                await self?.dispatchChangeHandler()
            }
            self?.assumeIsolated { $0.trackStateUpdate() } // TODO: remove this anyways when we move away form observation tracking
        }
    }

    /// Returns once the change handler completes.
    private func dispatchChangeHandler() async {
        guard case let .value(closure) = onChangeClosure else {
            return
        }

        let value = peripheral[keyPath: keyPath]
        await closure(value)
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
