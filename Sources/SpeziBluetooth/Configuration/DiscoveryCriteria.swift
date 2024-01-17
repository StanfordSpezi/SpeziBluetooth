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
}

extension DiscoveryCriteria: Hashable, CustomStringConvertible {
    public var description: String {
        switch self {
        case let .primaryService(uuid):
            ".primaryService(\(uuid))"
        }
    }
}
