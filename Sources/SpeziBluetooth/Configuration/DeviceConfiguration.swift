//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


public struct DeviceConfiguration {
    let discoveryCriteria: DiscoveryCriteria
    let anyDeviceType: any BluetoothDevice.Type


    init(discoveryCriteria: DiscoveryCriteria, anyDeviceType: any BluetoothDevice.Type) {
        self.discoveryCriteria = discoveryCriteria
        self.anyDeviceType = anyDeviceType
    }
}


extension DeviceConfiguration: Hashable {
    public static func == (lhs: DeviceConfiguration, rhs: DeviceConfiguration) -> Bool {
        lhs.discoveryCriteria == rhs.discoveryCriteria
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(discoveryCriteria)
    }
}
