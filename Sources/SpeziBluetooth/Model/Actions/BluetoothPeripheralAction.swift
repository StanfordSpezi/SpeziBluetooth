//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

/// The content of an implemented peripheral action.
public enum _PeripheralActionContent<ClosureType> { // swiftlint:disable:this type_name file_types_order
    /// Execute the action on the provided bluetooth peripheral.
    case peripheral(BluetoothPeripheral)
    /// Execute the injected closure instead.
    case injected(ClosureType)
}


/// A action that can be reference using ``DeviceAction``.
///
/// To implement a device action, implement a conforming type that implements
/// a `callAsFunction()` method and declare the respective extension to ``DeviceActions``.
public protocol _BluetoothPeripheralAction { // swiftlint:disable:this type_name
    /// The closure type of the action.
    associatedtype ClosureType

    /// Create a new action for a given peripheral instance.
    /// - Parameter content: The action content.
    init(_ content: _PeripheralActionContent<ClosureType>)
}
