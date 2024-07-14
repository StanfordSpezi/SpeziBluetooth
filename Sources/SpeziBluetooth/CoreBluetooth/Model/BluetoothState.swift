//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import CoreBluetooth


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


extension BluetoothState: RawRepresentable, AtomicValue {}


extension BluetoothState: Hashable, Sendable {}


extension BluetoothState: CustomStringConvertible {
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


extension BluetoothState {
    /// Derive peripheral state from CoreBluetooth
    public init(from state: CBManagerState) {
        switch state {
        case .unknown:
            self = .unknown
        case .resetting:
            self = .poweredOff
        case .unsupported:
            self = .unsupported
        case .unauthorized:
            self = .unauthorized
        case .poweredOff:
            self = .poweredOff
        case .poweredOn:
            self = .poweredOn
        @unknown default:
            self = .unknown
        }
    }
}
