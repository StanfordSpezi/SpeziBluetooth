//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth


/// The criteria by which we identify a discovered device.
///
/// ## Topics
///
/// ### Criteria
/// - ``advertisedService(_:)-5o92s``
/// - ``advertisedService(_:)-3pnr6``
/// - ``advertisedService(_:)-swift.enum.case``
public enum DiscoveryCriteria: Sendable {
    /// Identify a device by their advertised service.
    case advertisedService(_ uuid: CBUUID)
    /// Identify a device by its manufacturer and advertised service.
    case accessory(manufacturer: ManufacturerIdentifier, advertising: CBUUID)


    var discoveryId: CBUUID {
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
            return advertisementData.serviceUUIDs?.contains(uuid) ?? false
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
    /// - Parameter uuid: The Bluetooth service id in string format.
    /// - Returns: A ``DiscoveryCriteria/advertisedService(_:)-swift.enum.case`` criteria.
    public static func advertisedService(_ uuid: String) -> DiscoveryCriteria {
        .advertisedService(CBUUID(string: uuid))
    }

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
    ///   - service: The Bluetooth service id in string format.
    /// - Returns: A ``DiscoveryCriteria/accessory(manufacturer:advertising:)-swift.enum.case`` criteria.
    public static func accessory(manufacturer: ManufacturerIdentifier, advertising service: String) -> DiscoveryCriteria {
        .accessory(manufacturer: manufacturer, advertising: CBUUID(string: service))
    }

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
