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
/// - ``advertisedService(_:)-79pid``
/// - ``advertisedService(_:)-5o92s``
/// - ``advertisedServices(_:)-swift.type.method``
/// - ``advertisedServices(_:)-swift.enum.case``
/// - ``advertisedServices(_:_:)``
/// - ``accessory(manufacturer:advertising:)-swift.type.method``
/// - ``accessory(manufacturer:advertising:)-swift.enum.case``
/// - ``accessory(manufacturer:advertising:_:)``
public enum DiscoveryCriteria {
    /// Identify a device by their advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    case advertisedServices(_ uuids: [BTUUID])
    /// Identify a device by its manufacturer and advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    case accessory(manufacturer: ManufacturerIdentifier, advertising: [BTUUID])


    var discoveryIds: [BTUUID] {
        switch self {
        case let .advertisedServices(uuids):
            uuids
        case let .accessory(_, serviceIds):
            serviceIds
        }
    }


    func matches(_ advertisementData: AdvertisementData) -> Bool {
        switch self {
        case let .advertisedServices(uuids):
            return uuids.allSatisfy { uuid in
                advertisementData.serviceUUIDs?.contains(uuid) ?? advertisementData.overflowServiceUUIDs?.contains(uuid) ?? false
            }
        case let .accessory(manufacturer, serviceIds):
            guard let manufacturerData = advertisementData.manufacturerData,
                  let identifier = ManufacturerIdentifier(data: manufacturerData) else {
                return false
            }

            guard identifier == manufacturer else {
                return false
            }


            return serviceIds.allSatisfy { uuid in
                advertisementData.serviceUUIDs?.contains(uuid) ?? advertisementData.overflowServiceUUIDs?.contains(uuid) ?? false
            }
        }
    }
}


extension DiscoveryCriteria: Sendable {}


extension DiscoveryCriteria {
    /// Identity a device by their advertised service.
    /// - Parameter uuid: The service uuid the service advertises.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedService(_ uuid: BTUUID) -> DiscoveryCriteria {
        .advertisedServices([uuid])
    }

    /// Identity a device by their advertised service.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameter uuid: The service uuids the service advertises.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedServices(_ uuid: BTUUID...) -> DiscoveryCriteria {
        .advertisedServices(uuid)
    }

    /// Identify a device by their advertised service.
    /// - Parameter service: The service type.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedService<Service: BluetoothService>(
        _ service: Service.Type
    ) -> DiscoveryCriteria {
        .advertisedServices(service.id)
    }

    /// Identify a device by their advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - service: The service type.
    ///   - additionalService: An optional parameter pack argument to supply additional service types the accessory is expected to advertise.
    /// - Returns: A ``DiscoveryCriteria/advertisedServices(_:)-swift.enum.case`` criteria.
    public static func advertisedServices<Service: BluetoothService, each S: BluetoothService>(
        _ service: Service.Type,
        _ additionalService: repeat (each S).Type
    ) -> DiscoveryCriteria {
        var serviceIds: [BTUUID] = [service.id]
        repeat serviceIds.append((each additionalService).id)

        return .advertisedServices(serviceIds)
    }
}


extension DiscoveryCriteria {
    /// Identify a device by its manufacturer and advertised services.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - uuids: The service uuids the service advertises.
    /// - Returns: A ``DiscoveryCriteria/accessory(manufacturer:advertising:)-swift.enum.case`` criteria.
    public static func accessory(manufacturer: ManufacturerIdentifier, advertising uuids: BTUUID...) -> DiscoveryCriteria {
        .accessory(manufacturer: manufacturer, advertising: uuids)
    }

    /// Identify a device by its manufacturer and advertised service.
    ///
    /// All supplied services need to be present in the advertisement.
    /// - Parameters:
    ///   - manufacturer: The Bluetooth SIG-assigned manufacturer identifier.
    ///   - service: The service type.
    ///   - additionalService: An optional parameter pack argument to supply additional service types the accessory is expected to advertise.
    /// - Returns: A ``DiscoveryCriteria/accessory(manufacturer:advertising:)-swift.enum.case`` criteria.
    public static func accessory<Service: BluetoothService, each S: BluetoothService>(
        manufacturer: ManufacturerIdentifier,
        advertising service: Service.Type,
        _ additionalService: repeat (each S).Type
    ) -> DiscoveryCriteria {
        var serviceIds: [BTUUID] = [service.id]
        repeat serviceIds.append((each additionalService).id)

        return .accessory(manufacturer: manufacturer, advertising: serviceIds)
    }
}


extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case let .advertisedServices(uuids):
            ".advertisedServices(\(uuids))"
        case let .accessory(manufacturer, service):
            "accessory(company: \(manufacturer), advertised: \(service))"
        }
    }
}
