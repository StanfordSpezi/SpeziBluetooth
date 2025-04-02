//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OrderedCollections


@Observable
@MainActor
class ConnectedDevicesModel: Sendable {
    /// We track the connected device for every BluetoothDevice type and index by peripheral identifier.
    private var connectedDevices: [ObjectIdentifier: OrderedDictionary<UUID, any BluetoothDevice>] = [:]

    nonisolated init() {}

    func update(with devices: [UUID: any BluetoothDevice]) {
        // remove devices that disconnected
        for (identifier, var devicesById) in connectedDevices {
            var update = false
            for id in devicesById.keys where devices[id] == nil {
                devicesById.removeValue(forKey: id)
                update = true
            }

            if update {
                connectedDevices[identifier] = devicesById.isEmpty ? nil : devicesById
            }
        }

        // add newly connected devices that are not injected yet
        for (uuid, device) in devices {
            guard connectedDevices[device.typeIdentifier]?[uuid] == nil else {
                continue // already present
            }

            // Newly connected device
            connectedDevices[device.typeIdentifier, default: [:]].updateValue(device, forKey: uuid)
        }
    }

    subscript(_ identifier: ObjectIdentifier) -> [(any BluetoothDevice)] {
        guard let values = connectedDevices[identifier]?.values else {
            return []
        }
        return Array(values)
    }
}


extension BluetoothDevice {
    fileprivate var typeIdentifier: ObjectIdentifier {
        ObjectIdentifier(Self.self)
    }
}
