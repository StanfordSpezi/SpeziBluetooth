//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import CoreBluetooth


@propertyWrapper
public class DeviceState<Value> { // TODO: can appear anywhere right?
    private let keyPath: KeyPath<BluetoothPeripheral, Value>

    public var wrappedValue: Value {
        guard let peripheral else {
            // TODO: what do we do?
            preconditionFailure("Injection should be present right??")
        }
        return peripheral[keyPath: keyPath]
    }

    var peripheral: BluetoothPeripheral?

    
    public init(_ keyPath: KeyPath<BluetoothPeripheral, Value>) {
        self.keyPath = keyPath
    }
}


public enum DiscoveryCriteria: Hashable {
    // TODO: any?
    // case name(_ name: String) // TODO: we could support name, but not in conjuction with primaryService
    // TODO: make .startsWith, .exactly (init with string literal), .endsWith
    case primaryService(_ uuid: CBUUID)
}

public struct ServiceConfiguration: Hashable {
    public let serviceId: CBUUID
    public let characteristics: [CBUUID]


    public init(serviceId: CBUUID, characteristics: [CBUUID]) {
        self.serviceId = serviceId
        self.characteristics = characteristics
    }
}

public struct DiscoveryConfiguration {
    public let criteria: DiscoveryCriteria
    public let services: Set<ServiceConfiguration>


    public init(criteria: DiscoveryCriteria, services: Set<ServiceConfiguration>) {
        self.criteria = criteria
        self.services = services
    }
}


extension DiscoveryConfiguration: Hashable {
    public static func == (lhs: DiscoveryConfiguration, rhs: DiscoveryConfiguration) -> Bool {
        lhs.criteria == rhs.criteria
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(criteria)
    }
}


public struct DeviceConfiguration { // TODO: Configuration DSL: "Discover"
    var discoveryCriteria: DiscoveryCriteria

    init(discoverBy discoveryCriteria: DiscoveryCriteria) {
        self.discoveryCriteria = discoveryCriteria
    }

    public static func device<Device: BluetoothDevice>(
        discoverBy discoveryCriteria: DiscoveryCriteria,
        ofType: Device.Type = Device.self // TODO: escaping autoclosure for pre-configured device instances?
    ) -> DeviceConfiguration {
        // TODO: how to store the whole thingy?
        DeviceConfiguration(discoverBy: discoveryCriteria)
    }
}

// TODO: let bl = Bluetooth(devices: .device(identifiedBy: .name("Hello World"))) // TODO: DSL based approach?

public protocol BluetoothDevice: AnyObject {
    // TODO: somehow allow access to general device state (connected?, name?, undlerying CBPeripheral?)
    init()
}
