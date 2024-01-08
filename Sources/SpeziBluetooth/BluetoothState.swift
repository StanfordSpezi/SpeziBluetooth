//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Represents the various states of a Bluetooth module.
public enum BluetoothState: String {
    /// The Bluetooth module is turned off.
    case poweredOff

    // TODO: docs
    case unsupported

    /// The application does not have permission to use Bluetooth features.
    case unauthorized

    // TODO: docs
    case poweredOn
    
    /// The Bluetooth module is not connected to any device.
    // TODO: case disconnected
    
    /// The Bluetooth module is actively scanning for nearby devices.
    // TODO: case scanning
    
    /// The Bluetooth module is successfully connected to a device.
    // TODO: case connected
}

// TODO: localized string representable?
