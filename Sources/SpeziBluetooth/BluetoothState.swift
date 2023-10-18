//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Represents the various states of a Bluetooth component.
public enum BluetoothState: String {
    /// The Bluetooth component is turned off.
    case poweredOff
    
    /// The application does not have permission to use Bluetooth features.
    case unauthorized
    
    /// The Bluetooth component is not connected to any device.
    case disconnected
    
    /// The Bluetooth component is actively scanning for nearby devices.
    case scanning
    
    /// The Bluetooth component is successfully connected to a device.
    case connected
}
