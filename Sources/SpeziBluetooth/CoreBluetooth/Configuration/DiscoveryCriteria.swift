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
/// - ``advertisedService(_:)``
/// - ``primaryService(_:)-swift.enum.case``
/// - ``primaryService(_:)-swift.type.method``
public enum DiscoveryCriteria {
    // TODO: any?
    // case name(_ name: String) // TODO: we could support name, but not in conjunction with primaryService
    // TODO: make .startsWith, .exactly (init with string literal), .endsWith

    case advertisedService(_ uuid: CBUUID)
    /// Identify a device by the advertised primary service.
    case primaryService(_ uuid: CBUUID) // TODO: primary service and advertised services are two different things!!!!


    /// Identify a device by the advertised primary service.
    /// - Parameter uuid: The Bluetooth ServiceId in string format.
    /// - Returns: A ``DiscoveryCriteria/primaryService(_:)-swift.enum.case`` criteria.
    public static func primaryService(_ uuid: String) -> DiscoveryCriteria {
        .primaryService(CBUUID(string: uuid))
    }


    func matches(_ advertisementData: AdvertisementData) -> Bool {
        switch self {
        case let .primaryService(uuid):
            return advertisementData.serviceUUIDs?.contains(uuid) ?? false
            // TODO: we could easily support name as well (if we support the performance degradation impact!)
        case let .advertisedService(uuid):
            return advertisementData.serviceUUIDs?.contains(uuid) ?? false
        }
    }
}

extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case let .primaryService(uuid):
            ".primaryService(\(uuid))"
        case let .advertisedService(uuid):
            ".advertisedService(\(uuid))"
        }
    }
}
