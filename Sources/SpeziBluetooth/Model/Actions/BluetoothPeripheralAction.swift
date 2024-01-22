//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// A action that can be reference using ``DeviceAction``.
///
/// To implement a device action, implement a conforming type that implements
/// a `callAsFunction()` method and declare the respective extension to ``DeviceActions``.
public protocol _BluetoothPeripheralAction { // swiftlint:disable:this type_name
    /// Create a new action for a given peripheral instance.
    /// - Parameter peripheral: The bluetooth peripheral instance.
    init(from peripheral: BluetoothPeripheral)
}
