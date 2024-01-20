//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Represents the various states of Bluetooth.
public enum BluetoothState: UInt8 {
    /// Bluetooth module is powered off.
    case poweredOff

    /// Bluetooth is unsupported on this device (e.g.,
    case unsupported

    /// The application does not have permission to use Bluetooth features.
    case unauthorized

    /// Bluetooth is powered on and usable.
    case poweredOn
}


extension BluetoothState: CustomStringConvertible, Sendable {
    public var description: String {
        switch self {
        case .poweredOff:
            "poweredOff"
        case .unsupported:
            "unsupported"
        case .unauthorized:
            "unauthorized"
        case .poweredOn:
            "poweredOn"
        }
    }
}
