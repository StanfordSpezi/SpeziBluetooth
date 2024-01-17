//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


public struct Discover<Device: BluetoothDevice> {
    let deviceType: Device.Type
    let discoveryCriteria: DiscoveryCriteria


    public init(_ device: Device.Type, by discoveryCriteria: DiscoveryCriteria) {
        self.deviceType = device
        self.discoveryCriteria = discoveryCriteria
    }
}
