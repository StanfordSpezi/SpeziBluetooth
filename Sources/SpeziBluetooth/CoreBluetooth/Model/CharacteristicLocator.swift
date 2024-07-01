//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


struct CharacteristicLocator {
    let serviceId: CBUUID
    let characteristicId: CBUUID
}


extension CharacteristicLocator: Hashable, Sendable {}

extension CharacteristicLocator: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "\(characteristicId)@\(serviceId)"
    }

    public var debugDescription: String {
        "CharacteristicLocator(service: \(serviceId), characteristic: \(characteristicId))"
    }
}
