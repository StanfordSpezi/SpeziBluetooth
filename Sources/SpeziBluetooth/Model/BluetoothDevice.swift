//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation

// TODO: file name?

public protocol BluetoothDevice: AnyObject {
    // TODO: somehow allow access to general device state (connected?, name?, undlerying CBPeripheral?)
}


public enum DiscoveryCriteria: Hashable {
    // TODO: any?
    // TODO: others?
    case name(_ name: String) // TODO: does that make sense?
    case primaryService(_ uuid: CBUUID)
}

public struct DeviceConfiguration {
    var discoveryCriteria: DiscoveryCriteria

    init(discoverBy discoveryCriteria: DiscoveryCriteria) {
        self.discoveryCriteria = discoveryCriteria
    }
    // TODO: identifiying aspect: name, MAC?, primary service (don't consider secondary service)

    public static func device<Device: BluetoothDevice>(
        discoverBy discoveryCriteria: DiscoveryCriteria,
        ofType: Device.Type = Device.self // TODO: escaping autoclosure for pre-configured device instances
    ) -> DeviceConfiguration {
        // TODO: how to store the whole thingy?
        DeviceConfiguration(discoverBy: discoveryCriteria)
    }
}

// TODO: let bl = Bluetooth(devices: .device(identifiedBy: .name("Hello World"))) // TODO: DSL based approach?
