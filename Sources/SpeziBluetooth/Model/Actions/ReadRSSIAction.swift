//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Read the current RSSI from the Bluetooth peripheral.
///
/// For more information refer to ``DeviceActions/readRSSI``
public struct ReadRSSIAction: _BluetoothPeripheralAction {
    private let peripheral: BluetoothPeripheral

    @_documentation(visibility: internal)
    public init(from peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
    }


    @discardableResult
    public func callAsFunction() async throws -> Int {
        try await peripheral.readRSSI()
    }
}
