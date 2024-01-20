//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


@Observable
class ConnectedDevices {
    @MainActor private var connectedDevices: [ObjectIdentifier: BluetoothDevice] = [:]
    @MainActor private var connectedDeviceIds: [ObjectIdentifier: UUID] = [:]


    @MainActor
    func update(with devices: [UUID: BluetoothDevice]) {
        // remove devices that disconnected
        for (identifier, uuid) in connectedDeviceIds where devices[uuid] == nil {
            connectedDeviceIds.removeValue(forKey: identifier)
            connectedDevices.removeValue(forKey: identifier)
        }

        // add newly connected devices that are not injected yet
        for (uuid, device) in devices {
            guard connectedDevices[device.typeIdentifier] == nil else {
                continue // already present, we just inject the first device of a particular type into the environment
            }

            // Newly connected device for a type that isn't present yet. Save both device and id.
            connectedDevices[device.typeIdentifier] = device
            connectedDeviceIds[device.typeIdentifier] = uuid
        }
    }

    @MainActor
    subscript(_ identifier: ObjectIdentifier) -> BluetoothDevice? {
        connectedDevices[identifier]
    }
}


extension BluetoothDevice {
    fileprivate var typeIdentifier: ObjectIdentifier {
        ObjectIdentifier(Self.self)
    }
}
