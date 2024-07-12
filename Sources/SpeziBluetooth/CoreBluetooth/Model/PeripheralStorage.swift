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
final class PeripheralStorage: ValueObservable, Sendable {
    nonisolated var name: String? {
        _peripheralName ?? _localName
    }

    // swiftlint:disable identifier_name
    private(set) nonisolated(unsafe) var _peripheralName: String?
    private(set) nonisolated(unsafe) var _localName: String?
    private(set) nonisolated(unsafe) var _rssi: Int
    private(set) nonisolated(unsafe) var _advertisementData: AdvertisementData
    private(set) nonisolated(unsafe) var _state: PeripheralState
    private(set) nonisolated(unsafe) var _nearby: Bool
    private(set) nonisolated(unsafe) var _services: [GATTService]? // swiftlint:disable:this discouraged_optional_collection
    private(set) nonisolated(unsafe) var _lastActivity: Date
    // swiftlint:enable identifier_name

    @SpeziBluetooth var peripheralName: String? {
        get {
            _peripheralName
        }
        set {
            let didChange = newValue != _peripheralName
            _peripheralName = newValue
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.peripheralName, on: self)
            }
        }
    }

    @SpeziBluetooth var localName: String? {
        get {
            _localName
        }
        set {
            let didChange = newValue != _localName
            _localName = newValue
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.localName, on: self)
            }
        }
    }

    @SpeziBluetooth var rssi: Int {
        get {
            _rssi
        }
        set {
            let didChange = newValue != _rssi
            _rssi = newValue
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.rssi, on: self)
            }
        }
    }

    @SpeziBluetooth var advertisementData: AdvertisementData {
        get {
            _advertisementData
        }
        set {
            let didChange = newValue != _advertisementData
            _advertisementData = newValue
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.advertisementData, on: self)
            }
        }
    }

    @SpeziBluetooth var state: PeripheralState {
        get {
            _state
        }
        set {
            let didChange = newValue != _state
            _state = newValue
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.state, on: self)
            }
        }
    }

    @SpeziBluetooth var nearby: Bool {
        get {
            _nearby
        }
        set {
            _nearby = newValue
            _$simpleRegistrar.triggerDidChange(for: \.nearby, on: self)
        }
    }

    @SpeziBluetooth var services: [GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        get {
            _services
        }
        set {
            _services = newValue
            _$simpleRegistrar.triggerDidChange(for: \.services, on: self)
        }
    }

    @SpeziBluetooth var lastActivity: Date {
        get {
            _lastActivity
        }
        set {
            _lastActivity = newValue
            _$simpleRegistrar.triggerDidChange(for: \.lastActivity, on: self)
        }
    }

    // swiftlint:disable:next identifier_name
    @ObservationIgnored let _$simpleRegistrar = ValueObservationRegistrar<PeripheralStorage>()

    init(peripheralName: String?, rssi: Int, advertisementData: AdvertisementData, state: CBPeripheralState, lastActivity: Date = .now) {
        self._peripheralName = peripheralName
        self._localName = advertisementData.localName
        self._advertisementData = advertisementData
        self._rssi = rssi
        self._state = .init(from: state)
        self._nearby = false
        self._lastActivity = lastActivity
    }

    @SpeziBluetooth
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

    @SpeziBluetooth
    func update(nearby: Bool) {
        if nearby != self.nearby {
            self.nearby = nearby
        }
    }

    @SpeziBluetooth
    func signalFullyDiscovered() {
        if state == .connecting {
            state = .connected
            update(state: .connected) // ensure other logic is called as well
        }
    }

    @SpeziBluetooth
    func update(lastActivity: Date = .now) {
        self.lastActivity = lastActivity
    }

    @SpeziBluetooth
    func update(services: [GATTService]?) { // swiftlint:disable:this discouraged_optional_collection
        self.services = services
    }
}
