//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// Represents a Bluetooth service with its associated characteristics.
public struct BluetoothService {
    /// The unique identifier for the Bluetooth service.
    public let serviceUUID: CBUUID
    
    /// A list of unique identifiers for the characteristics associated with the service.
    public let characteristicUUIDs: [CBUUID]
    
    /// Initializes a new Bluetooth service with the specified service UUID and characteristic UUIDs.
    ///
    /// - Parameters:
    ///   - serviceUUID: The unique identifier for the Bluetooth service.
    ///   - characteristicUUIDs: A list of unique identifiers for the characteristics associated with the service.
    public init(serviceUUID: CBUUID, characteristicUUIDs: [CBUUID]) {
        self.serviceUUID = serviceUUID
        self.characteristicUUIDs = characteristicUUIDs
    }
}
