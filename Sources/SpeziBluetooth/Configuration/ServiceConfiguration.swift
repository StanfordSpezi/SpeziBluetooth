//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// The service configuration for a certain device.
///
/// Describes what a certain service we expect to be present for a given device.
public struct ServiceConfiguration {
    /// The service id.
    public let serviceId: CBUUID
    /// The characteristics present on the service.
    ///
    /// Those are the characteristics we try to discover. If empty, we discover all characteristics
    /// on a given service.
    public let characteristics: [CBUUID]


    /// Create a new service configuration.
    /// - Parameters:
    ///   - serviceId: The bluetooth service id.
    ///   - characteristics: The characteristics we expect to be present on the service.
    public init(serviceId: CBUUID, characteristics: [CBUUID]) {
        self.serviceId = serviceId
        self.characteristics = characteristics
    }
}

extension ServiceConfiguration: Hashable {}
