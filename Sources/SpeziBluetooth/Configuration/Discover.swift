//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Declare how a bluetooth device is discovered.
///
/// Declares by which ``DiscoveryCriteria`` a given ``BluetoothDevice`` implementation is discovered.
///
/// - Note: The criteria must be unique across all discovery configurations.
public struct Discover<Device: BluetoothDevice> {
    let deviceType: Device.Type
    let discoveryCriteria: DiscoveryCriteria


    /// Create a discovery for a given device type.
    /// - Parameters:
    ///   - device: The type of a ``BluetoothDevice`` implementation.
    ///   - discoveryCriteria: The criteria by which the device is discovered.
    public init(_ device: Device.Type, by discoveryCriteria: DiscoveryCriteria) {
        self.deviceType = device
        self.discoveryCriteria = discoveryCriteria
    }
}
