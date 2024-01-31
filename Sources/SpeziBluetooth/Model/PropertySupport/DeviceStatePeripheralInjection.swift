//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation


class DeviceStatePeripheralInjection<Value> {
    let peripheral: BluetoothPeripheral
    private let keyPath: KeyPath<BluetoothPeripheral, Value>

    private var onChangeClosure: ((Value) async -> Void)?


    init(peripheral: BluetoothPeripheral, keyPath: KeyPath<BluetoothPeripheral, Value>, onChangeClosure: ((Value) async -> Void)?) {
        self.peripheral = peripheral
        self.keyPath = keyPath
        self.onChangeClosure = onChangeClosure
    }

    func setup() {
        trackStateUpdate()
    }

    private func trackStateUpdate() {
        withObservationTracking {
            _ = peripheral[keyPath: keyPath]
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                await self?.executeChangeHandler()
            }
            self?.trackStateUpdate()
        }
    }

    private func executeChangeHandler() async {
        guard let onChangeClosure else {
            return
        }

        let value = peripheral[keyPath: keyPath]
        await onChangeClosure(value)
    }

    func clearState() {
        onChangeClosure = nil
    }

    nonisolated func setOnChangeClosure(_ closure: ((Value) async -> Void)?) {
        self.onChangeClosure = closure
    }
}
