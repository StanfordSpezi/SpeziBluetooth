//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog


/// The description for a certain type of device.
///
/// Describes what services we expect to be present for a certain type of device.
/// The ``BluetoothManager`` uses that to determine what devices to discover and what services and characteristics to expect.
public struct DeviceDescription {
    /// The criteria by which we identify a discovered device.
    public let discoveryCriteria: DiscoveryCriteria
    /// The set of service configurations we expect from the device.
    ///
    /// This will be the list of services we are interested in and we try to discover.
    public let services: Set<ServiceDescription>? // swiftlint:disable:this discouraged_optional_collection


    /// Create a new discovery configuration for a certain type of device.
    /// - Parameters:
    ///   - discoveryCriteria: The criteria by which we identify a discovered device.
    ///   - services: The set of service configurations we expect from the device.
    ///     Use `nil` to discover all services.
    public init(discoverBy discoveryCriteria: DiscoveryCriteria, services: Set<ServiceDescription>?) {
        // swiftlint:disable:previous discouraged_optional_collection
        self.discoveryCriteria = discoveryCriteria
        self.services = services
    }
}


extension DeviceDescription: Identifiable {
    public var id: DiscoveryCriteria {
        discoveryCriteria
    }
}


extension DeviceDescription: Hashable {
    public static func == (lhs: DeviceDescription, rhs: DeviceDescription) -> Bool {
        lhs.discoveryCriteria == rhs.discoveryCriteria
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(discoveryCriteria)
    }
}


extension Collection where Element: Identifiable, Element.ID == DiscoveryCriteria {
    func find(for advertisementData: AdvertisementData, logger: Logger) -> Element? {
        let configurations = filter { configuration in
            configuration.id.matches(advertisementData)
        }

        if configurations.count > 1 {
            let criteria = configurations
                .map { $0.id.description }
                .joined(separator: ", ")
            logger.warning("Found ambiguous discovery configuration for peripheral. Peripheral matched all these criteria: \(criteria)")
        }

        return configurations.first
    }
}
