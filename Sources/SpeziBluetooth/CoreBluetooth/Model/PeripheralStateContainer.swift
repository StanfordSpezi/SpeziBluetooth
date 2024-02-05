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
    private(set) var peripheralName: String?
    private(set) var localName: String?
    private(set) var rssi: Int
    private(set) var advertisementData: AdvertisementData
    private(set) var state: PeripheralState
    private(set) var services: [GATTService]? // swiftlint:disable:this discouraged_optional_collection
    @ObservationIgnored var lastActivity: Date

    init(peripheralName: String?, rssi: Int, advertisementData: AdvertisementData, state: CBPeripheralState, lastActivity: Date = .now) {
        self.peripheralName = peripheralName
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

    func update(state: PeripheralState) {
        if self.state != state {
            if self.state == .connecting && state == .connected {
                return // we set connected on our own!
            }
            self.state = state
        }
    }

    func signalFullyDiscovered() {
        if state == .connecting {
            state = .connected
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
