//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// A service description for a certain device.
///
/// Describes what characteristics we expect to be present for a certain service.
public struct ServiceDescription: Sendable {
    /// The service id.
    public let serviceId: BTUUID
    /// The description of characteristics present on the service.
    ///
    /// Those are the characteristics we try to discover.
    /// - Note: If `nil`, we discover all characteristics on a given service.
    public var characteristics: Set<CharacteristicDescription>? { // swiftlint:disable:this discouraged_optional_collection
        let values: Dictionary<BTUUID, CharacteristicDescription>.Values? = _characteristics?.values
        return values.map { Set($0) }
    }

    private let _characteristics: [BTUUID: CharacteristicDescription]? // swiftlint:disable:this discouraged_optional_collection

    /// Create a new service description.
    /// - Parameters:
    ///   - serviceId: The bluetooth service id.
    ///   - characteristics: The description of characteristics we expect to be present on the service.
    ///     Use `nil` to discover all characteristics.
    public init(serviceId: BTUUID, characteristics: Set<CharacteristicDescription>?) { // swiftlint:disable:this discouraged_optional_collection
        self.serviceId = serviceId
        self._characteristics = characteristics?.reduce(into: [:]) { partialResult, description in
            partialResult[description.characteristicId] = description
        }
    }


    /// Retrieve the characteristic description for a given service id.
    /// - Parameter characteristicsId: The Bluetooth characteristic id.
    /// - Returns: Returns the characteristic description if present.
    public func description(for characteristicsId: BTUUID) -> CharacteristicDescription? {
        _characteristics?[characteristicsId]
    }
}


extension ServiceDescription: Hashable {}
