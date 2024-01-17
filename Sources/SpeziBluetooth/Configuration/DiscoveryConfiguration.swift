//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// The discovery configuration for a certain type of device.
public struct DiscoveryConfiguration {
    /// The criteria by which we identify a discovered device.
    public let criteria: DiscoveryCriteria
    /// The set of service configurations we expect from the device.
    ///
    /// This will be the list of services we are interested in and we try to discover.
    public let services: Set<ServiceConfiguration>


    /// Create a new discovery configuration for a certain type of device.
    /// - Parameters:
    ///   - criteria: The criteria by which we identify a discovered device.
    ///   - services: The set of service configurations we expect from the device.
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
