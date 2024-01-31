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
    // SYNCED TO PERIPHERAL ACTOR
    private(set) var peripheralName: String?
    private(set) var localName: String?
    private(set) var rssi: Int
    private(set) var advertisementData: AdvertisementData
    private(set) var state: PeripheralState
    private(set) var services: [GATTService]? // swiftlint:disable:this discouraged_optional_collection

    /// SYNCED TO THE BLUETOOTH MANAGER DISPATCH QUEUE
    private(set) var lastActivity: Date

    var name: String? {
        localName ?? peripheralName
    }

    init(name: String?, rssi: Int, advertisementData: AdvertisementData, state: CBPeripheralState, lastActivity: Date = .now) {
        self.peripheralName = name
        self.localName = advertisementData.localName
        self.advertisementData = advertisementData
        self.rssi = rssi
        self.state = .init(from: state)
        self.lastActivity = lastActivity
    }

    func update(localName: String?) {
        if self.localName != localName {
            self.localName = localName
        }
    }

    func update(peripheralName: String?) {
        if self.peripheralName != peripheralName {
            self.peripheralName = peripheralName
        }
    }

    func update(rssi: Int) {
        if self.rssi != rssi {
            self.rssi = rssi
        }
    }

    func update(advertisementData: AdvertisementData) {
        self.advertisementData = advertisementData // not equatable
    }

    func update(state cbState: CBPeripheralState) {
        let state = PeripheralState(from: cbState)
        if self.state != state {
            self.state = state
        }
    }

    func update(lastActivity: Date = .now) {
        self.lastActivity = lastActivity
    }

    func assign(services: [GATTService]) {
        self.services = services
    }

    func invalidateServices(_ ids: [CBUUID]) {
        for id in ids {
            guard let index = services?.firstIndex(where: { $0.uuid == id }) else {
                continue
            }

            services?.remove(at: index)
        }
    }
}
