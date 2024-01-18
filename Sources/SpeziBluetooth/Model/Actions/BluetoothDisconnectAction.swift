//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Disconnect from the Bluetooth peripheral.
///
/// For more information refer to ``DeviceActions/disconnect``
public struct BluetoothDisconnectAction: _BluetoothPeripheralAction {
    private let peripheral: BluetoothPeripheral

    @_documentation(visibility: internal)
    public init(from peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
    }

    public func callAsFunction() async {
        await peripheral.disconnect()
    }
}
