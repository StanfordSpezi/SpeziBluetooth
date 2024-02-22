//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth


/// A generic bluetooth peripheral representation used within UI components.
public protocol GenericBluetoothPeripheral {
    /// The user-visible label.
    ///
    /// This label is used to communicate information about this device to the user.
    var label: String { get }

    /// An optional accessibility label.
    ///
    /// This label is used as the accessibility label within views when
    /// communicate information about this device to the user.
    var accessibilityLabel: String { get }

    /// The current peripheral state.
    var state: PeripheralState { get }

    /// Mark the device to require user attention.
    ///
    /// Marks the device to require user attention. The user should navigate to the details
    /// view to get more information about the device.
    var requiresUserAttention: Bool { get }
}


extension GenericBluetoothPeripheral {
    /// Default implementation using the devices `label`.
    public var accessibilityLabel: String {
        label
    }

    /// By default the peripheral doesn't require user attention.
    public var requiresUserAttention: Bool {
        false
    }
}
