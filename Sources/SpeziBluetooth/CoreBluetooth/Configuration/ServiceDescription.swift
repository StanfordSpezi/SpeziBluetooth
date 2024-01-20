//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// A service description for a certain device.
///
/// Describes what characteristics we expect to be present for a certain service.
public struct ServiceDescription {
    /// The service id.
    public let serviceId: CBUUID
    /// The characteristics present on the service.
    ///
    /// Those are the characteristics we try to discover. If empty, we discover all characteristics
    /// on a given service.
    public let characteristics: Set<CBUUID>? // swiftlint:disable:this discouraged_optional_collection


    /// Create a new service description.
    /// - Parameters:
    ///   - serviceId: The bluetooth service id.
    ///   - characteristics: The characteristics we expect to be present on the service.
    ///     Use `nil` to discover all characteristics.
    public init(serviceId: CBUUID, characteristics: Set<CBUUID>?) { // swiftlint:disable:this discouraged_optional_collection
        self.serviceId = serviceId
        self.characteristics = characteristics
    }


    /// Create a new service description using strings.
    /// - Parameters:
    ///   - serviceId: The bluetooth service id string.
    ///   - characteristics: The characteristics we expect to be present on the service.
    public init(serviceId: String, characteristics: Set<String>) {
        self.init(serviceId: CBUUID(string: serviceId), characteristics: Set(characteristics.map { CBUUID(string: $0) }))
    }
}


extension ServiceDescription: Hashable {}
