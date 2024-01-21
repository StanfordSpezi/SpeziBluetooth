//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// The criteria by which we identify a discovered device.
///
/// ## Topics
///
/// ### Criteria
/// - ``advertisedService(_:)-swift.enum.case``
/// - ``advertisedService(_:)-swift.type.method``
public enum DiscoveryCriteria {
    /// Identify a device by their advertised service.
    case advertisedService(_ uuid: CBUUID)


    var discoveryId: CBUUID {
        switch self {
        case let .advertisedService(uuid):
            uuid
        }
    }


    /// Identify a device by their advertised service.
    /// - Parameter uuid: The Bluetooth ServiceId in string format.
    /// - Returns: A ``DiscoveryCriteria/advertisedService(_:)-swift.enum.case`` criteria.
    public static func advertisedService(_ uuid: String) -> DiscoveryCriteria {
        .advertisedService(CBUUID(string: uuid))
    }


    func matches(_ advertisementData: AdvertisementData) -> Bool {
        switch self {
        case let .advertisedService(uuid):
            return advertisementData.serviceUUIDs?.contains(uuid) ?? false
        }
    }
}

extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case let .advertisedService(uuid):
            ".advertisedService(\(uuid))"
        }
    }
}
