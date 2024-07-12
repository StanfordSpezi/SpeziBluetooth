//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


final class DeviceActionPeripheralInjection: Sendable {
    private let bluetooth: Bluetooth
    let peripheral: BluetoothPeripheral


    init(bluetooth: Bluetooth, peripheral: BluetoothPeripheral) {
        self.bluetooth = bluetooth
        self.peripheral = peripheral
    }


    deinit {
        bluetooth.notifyDeviceDeinit(for: peripheral.id)
    }
}
