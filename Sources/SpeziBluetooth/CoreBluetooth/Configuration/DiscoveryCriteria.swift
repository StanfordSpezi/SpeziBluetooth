//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// The criteria by which we identify a discovered device.
///
/// ## Topics
///
/// ### Criteria
/// - ``advertisedService(_:)-swift.type.method``
/// - ``advertisedService(_:)-swift.enum.case``
/// - ``accessory(manufacturer:advertising:)-swift.type.method``
/// - ``accessory(manufacturer:advertising:)-swift.enum.case``
public enum DiscoveryCriteria: Sendable {
    /// Identify a device by their advertised service.
    case advertisedService(_ uuid: BTUUID)
    /// Identify a device by its manufacturer and advertised service.
    case accessory(manufacturer: ManufacturerIdentifier, advertising: BTUUID)


    var discoveryId: BTUUID {
        switch self {
        case let .advertisedService(uuid):
            uuid
        case let .accessory(_, service):
            service
        }
    }


    func matches(_ advertisementData: AdvertisementData) -> Bool {
        switch self {
        case let .advertisedService(uuid):
            return advertisementData.serviceUUIDs?.contains(uuid) ?? advertisementData.overflowServiceUUIDs?.contains(uuid) ?? false
        case let .accessory(manufacturer, service):
            guard let manufacturerData = advertisementData.manufacturerData,
                  let identifier = ManufacturerIdentifier(data: manufacturerData) else {
                return false
            }

            guard identifier == manufacturer else {
                return false
            }


            return advertisementData.serviceUUIDs?.contains(service) ?? false
        }
    }
}


extension DiscoveryCriteria {
    /// Identify a device by their advertised service.
    /// - Parameter service: The service type.
    /// - Returns: A ``DiscoveryCriteria/advertisedService(_:)-swift.enum.case`` criteria.
    public static func advertisedService<Service: BluetoothService>(_ service: Service.Type) -> DiscoveryCriteria {
        .advertisedService(service.id)
    }
}


extension DiscoveryCriteria {
    /// Identify a device by its manufacturer and advertised service.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - service: The service type.
    /// - Returns: A ``DiscoveryCriteria/accessory(manufacturer:advertising:)-swift.enum.case`` criteria.
    public static func accessory<Service: BluetoothService>(
        manufacturer: ManufacturerIdentifier,
        advertising service: Service.Type
    ) -> DiscoveryCriteria {
        .accessory(manufacturer: manufacturer, advertising: service.id)
    }
}


extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case let .advertisedService(uuid):
            ".advertisedService(\(uuid))"
        case let .accessory(manufacturer, service):
            "accessory(company: \(manufacturer), advertised: \(service))"
        }
    }
}
