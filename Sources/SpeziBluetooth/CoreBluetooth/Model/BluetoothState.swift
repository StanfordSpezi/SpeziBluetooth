//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Represents the various states of Bluetooth.
public enum BluetoothState: UInt8 {
    /// The Bluetooth state is unknown.
    ///
    /// The state will become known once you start scanning for nearby devices or use Bluetooth.
    case unknown
    /// Bluetooth module is powered off.
    case poweredOff
    /// Bluetooth is unsupported on this device (e.g., on simulator devices).
    case unsupported
    /// The application does not have permission to use Bluetooth features.
    case unauthorized
    /// Bluetooth is powered on and usable.
    case poweredOn
}


extension BluetoothState: CustomStringConvertible, Sendable {
    public var description: String {
        switch self {
        case .unknown:
            "unknown"
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
