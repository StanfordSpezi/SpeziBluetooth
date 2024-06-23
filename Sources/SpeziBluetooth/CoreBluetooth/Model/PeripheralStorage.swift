//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


/// A dedicated, observable storage container for a ``BluetoothPeripheral``.
///
/// Main motivation is to have `BluetoothPeripheral` be implemented as an actor and moving state
/// into a separate state container that is `@Observable`.
@Observable
final class PeripheralStorage: ValueObservable {
    var name: String? {
        peripheralName ?? localName
    }

    private(set) var peripheralName: String? {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.peripheralName, on: self)
        }
    }

    private(set) var localName: String? {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.localName, on: self)
        }
    }

    private(set) var rssi: Int {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.rssi, on: self)
        }
    }

    private(set) var advertisementData: AdvertisementData {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.advertisementData, on: self)
        }
    }

    private(set) var state: PeripheralState {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.state, on: self)
        }
    }

    private(set) var nearby: Bool {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.nearby, on: self)
        }
    }

    private(set) var services: [GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.services, on: self)
        }
    }

    private(set) var lastActivity: Date {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.lastActivity, on: self)
        }
    }

    // swiftlint:disable:next identifier_name
    @ObservationIgnored var _$simpleRegistrar = ValueObservationRegistrar<PeripheralStorage>()

    init(peripheralName: String?, rssi: Int, advertisementData: AdvertisementData, state: CBPeripheralState, lastActivity: Date = .now) {
        self.peripheralName = peripheralName
        self.localName = advertisementData.localName
        self.advertisementData = advertisementData
        self.rssi = rssi
        self.state = .init(from: state)
        self.nearby = false
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
            // we set connected on our own! See `signalFullyDiscovered`
            if !(self.state == .connecting && state == .connected) {
                self.state = state
            }
        }

        if !nearby && (self.state == .connecting || self.state == .connected) {
            self.nearby = true
        }
    }

    func update(nearby: Bool) {
        if nearby != self.nearby {
            self.nearby = nearby
        }
    }

    func signalFullyDiscovered() {
        if state == .connecting {
            state = .connected
            update(state: .connected) // ensure other logic is called as well
        }
    }

    func update(lastActivity: Date = .now) {
        self.lastActivity = lastActivity
    }

    func assign(services: [GATTService]) {
        self.services = services
    }
}
