//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Connect to the Bluetooth peripheral.
///
/// For more information refer to ``DeviceActions/connect``
public struct BluetoothConnectAction: _BluetoothPeripheralAction {
    public typealias ClosureType = () async -> Void

    private let content: _PeripheralActionContent<ClosureType>

    @_documentation(visibility: internal)
    public init(_ content: _PeripheralActionContent<ClosureType>) {
        self.content = content
    }


    public func callAsFunction() async {
        switch content {
        case let .peripheral(peripheral):
            await peripheral.connect()
        case let .injected(closure):
            await closure()
        }
    }
}
