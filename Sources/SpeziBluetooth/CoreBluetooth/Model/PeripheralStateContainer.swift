//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


/// A dedicated state container for a ``BluetoothPeripheral``.
///
/// Main motivation is to have `BluetoothPeripheral` be implemented as an actor and moving state
/// into a separate state container that is `@Observable`.
@Observable
final class PeripheralStateContainer {
    var name: String?
    var rssi: Int
    var advertisementData: AdvertisementData
    var state: PeripheralState
    var lastActivity: Date

    var services: [CBService]? // swiftlint:disable:this discouraged_optional_collection

    /// The list of requested characteristic uuids indexed by service uuids.
    var requestedCharacteristics: [CBUUID: Set<CharacteristicDescription>?]? // swiftlint:disable:this discouraged_optional_collection

    init(name: String?, rssi: Int, advertisementData: AdvertisementData, state: CBPeripheralState, lastActivity: Date = .now) {
        self.name = name
        self.advertisementData = advertisementData
        self.rssi = rssi
        self.state = .init(from: state)
        self.lastActivity = lastActivity
    }
}
