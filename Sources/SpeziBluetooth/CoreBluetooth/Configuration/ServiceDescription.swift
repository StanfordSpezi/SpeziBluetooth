//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth


/// A service description for a certain device.
///
/// Describes what characteristics we expect to be present for a certain service.
public struct ServiceDescription: Sendable {
    /// The service id.
    public let serviceId: CBUUID
    /// The description of characteristics present on the service.
    ///
    /// Those are the characteristics we try to discover. If empty, we discover all characteristics
    /// on a given service.
    public let characteristics: Set<CharacteristicDescription>? // swiftlint:disable:this discouraged_optional_collection


    /// Create a new service description.
    /// - Parameters:
    ///   - serviceId: The bluetooth service id.
    ///   - characteristics: The description of characteristics we expect to be present on the service.
    ///     Use `nil` to discover all characteristics.
    public init(serviceId: CBUUID, characteristics: Set<CharacteristicDescription>?) { // swiftlint:disable:this discouraged_optional_collection
        self.serviceId = serviceId
        self.characteristics = characteristics
    }

    /// Create a new service description.
    /// - Parameters:
    ///   - serviceId: The bluetooth service id.
    ///   - characteristics: The description of characteristics we expect to be present on the service.
    ///     Use `nil` to discover all characteristics.
    public init(serviceId: String, characteristics: Set<CharacteristicDescription>?) { // swiftlint:disable:this discouraged_optional_collection
        self.init(serviceId: CBUUID(string: serviceId), characteristics: characteristics)
    }
}


extension ServiceDescription: Hashable {
    public static func == (lhs: ServiceDescription, rhs: ServiceDescription) -> Bool {
        lhs.serviceId == rhs.serviceId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(serviceId)
    }
}
