//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth

/// Bluetooth SIG-assigned Manufacturer Identifier.
///
/// Refer to Assigned Numbers 7. Company Identifiers.
public struct ManufacturerIdentifier {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}


extension ManufacturerIdentifier: Hashable, Sendable {}


extension ManufacturerIdentifier: RawRepresentable {}


extension ManufacturerIdentifier: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt16) {
        self.init(rawValue: value)
    }
}


import ByteCoding
import NIOCore
extension ManufacturerIdentifier: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt16(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
    
    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
    

}


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
    case accessory(company: ManufacturerIdentifier, name: String, service: CBUUID)
    // TODO: "company" vs "manufacturer"
    // TODO: name as a substring?; not local name!
    // TODO: how to communicate the "advertised" service?


    var discoveryId: CBUUID { // TODO: make that custom able?
        switch self {
        case let .advertisedService(uuid):
            uuid
        case let .accessory(_, _, service):
            service
        }
    }


    func matches(_ advertisementData: AdvertisementData) -> Bool {
        switch self {
        case let .advertisedService(uuid):
            return advertisementData.serviceUUIDs?.contains(uuid) ?? false
        case let .accessory(company, _, service):
            guard let manufacturerData = advertisementData.manufacturerData,
                  let identifier = ManufacturerIdentifier(data: manufacturerData) else {
                return false
            }

            guard identifier == company else {
                return false
            }

            // TODO: compare peripheral name! (substring?)


            return advertisementData.serviceUUIDs?.contains(service) ?? false
        }
    }
}


// TODO: similar overloads for accessory!
extension DiscoveryCriteria {
    /// Identify a device by their advertised service.
    /// - Parameter uuid: The Bluetooth ServiceId in string format.
    /// - Returns: A ``DiscoveryCriteria/advertisedService(_:)-swift.enum.case`` criteria.
    public static func advertisedService(_ uuid: String) -> DiscoveryCriteria {
        .advertisedService(CBUUID(string: uuid))
    }

    /// Identify a device by their advertised service.
    /// - Parameter service: The service type.
    /// - Returns: A ``DiscoveryCriteria/advertisedService(_:)-swift.enum.case`` criteria.
    public static func advertisedService<Service: BluetoothService>(_ service: Service.Type) -> DiscoveryCriteria {
        .advertisedService(Service.id)
    }
}


extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case let .advertisedService(uuid):
            ".advertisedService(\(uuid))"
        case let .accessory(company, name, service):
            "accessory(company: \(company), name: \(name), service: \(service))"
        }
    }
}
