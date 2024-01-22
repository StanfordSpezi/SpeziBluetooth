//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Collection of device actions available on a ``BluetoothPeripheral``.
///
/// Exposes the meta-types of all available actions of a Bluetooth Device as properties of this type.
///
/// ## Topics
///
/// ### Managing Connection
/// - ``connect``
/// - ``disconnect``
///
/// ### Retrieving current signal strength
/// - ``readRSSI``
///
/// ### Implementations
///
/// - ``BluetoothConnectAction``
/// - ``BluetoothDisconnectAction``
/// - ``ReadRSSIAction``
public struct DeviceActions {
    /// Connect to the Bluetooth peripheral.
    ///
    /// This action makes a call to ``BluetoothPeripheral/connect()``.
    public var connect: BluetoothConnectAction.Type {
        BluetoothConnectAction.self
    }

    /// Disconnect from the Bluetooth peripheral.
    ///
    /// This action makes a call to ``BluetoothPeripheral/disconnect()``.
    public var disconnect: BluetoothDisconnectAction.Type {
        BluetoothDisconnectAction.self
    }

    /// Retrieve the current signal strength.
    ///
    /// This action makes a call to ``BluetoothPeripheral/readRSSI()``
    public var readRSSI: ReadRSSIAction.Type {
        ReadRSSIAction.self
    }
}
