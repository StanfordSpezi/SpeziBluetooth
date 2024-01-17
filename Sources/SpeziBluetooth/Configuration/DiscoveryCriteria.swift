//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// The criteria by which we identify a discovered device.
public enum DiscoveryCriteria {
    // TODO: any?
    // case name(_ name: String) // TODO: we could support name, but not in conjunction with primaryService
    // TODO: make .startsWith, .exactly (init with string literal), .endsWith

    /// Identify a device by the advertised primary service.
    case primaryService(_ uuid: CBUUID)


    /// Identify a device by the advertised primary service.
    /// - Parameter uuid: The Bluetooth ServiceId in string format.
    /// - Returns: A ``DiscoveryCriteria/primaryService(_:)`` criteria.
    static func primaryService(_ uuid: String) -> DiscoveryCriteria {
        .primaryService(CBUUID(string: uuid))
    }
}

extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case let .primaryService(uuid):
            ".primaryService(\(uuid))"
        }
    }
}
