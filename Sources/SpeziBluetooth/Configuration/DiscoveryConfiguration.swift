//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Describes how to discover a given ``BluetoothDevice``.
public struct DiscoveryConfiguration: Sendable {
    let discoveryCriteria: DiscoveryCriteria
    let anyDeviceType: any BluetoothDevice.Type


    init(discoveryCriteria: DiscoveryCriteria, anyDeviceType: any BluetoothDevice.Type) {
        self.discoveryCriteria = discoveryCriteria
        self.anyDeviceType = anyDeviceType
    }
}


extension DiscoveryConfiguration: Identifiable {
    public var id: DiscoveryCriteria {
        discoveryCriteria
    }
}


extension DiscoveryConfiguration: Hashable {
    public static func == (lhs: DiscoveryConfiguration, rhs: DiscoveryConfiguration) -> Bool {
        lhs.discoveryCriteria == rhs.discoveryCriteria
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(discoveryCriteria)
    }
}
