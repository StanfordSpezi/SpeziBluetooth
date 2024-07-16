//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import Foundation


/// A dedicated, observable storage container for a ``BluetoothPeripheral``.
///
/// Main motivation is to have `BluetoothPeripheral` be implemented as an actor and moving state
/// into a separate state container that is `@Observable`.
@Observable
final class PeripheralStorage: ValueObservable, Sendable {
    private let _state: ManagedAtomic<PeripheralState>
    private let _rssi: ManagedAtomic<Int>
    private let _nearby: ManagedAtomic<Bool>
    private let _lastActivityTimeIntervalSince1970BitPattern: ManagedAtomic<UInt64> // workaround to store store Date atomically
    // swiftlint:disable:previous identifier_name

    @ObservationIgnored private nonisolated(unsafe) var _peripheralName: String?
    @ObservationIgnored private nonisolated(unsafe) var _advertisementData: AdvertisementData
    // Its fine to have a single lock. Readers will be isolated anyways to the SpeziBluetooth global actor.
    // The only side-effect is, that readers will wait for any write to complete, which is fine as peripheralName is rarely updated.
    private let lock = RWLock()

    @SpeziBluetooth var lastActivity: Date {
        didSet {
            _lastActivityTimeIntervalSince1970BitPattern.store(lastActivity.timeIntervalSince1970.bitPattern, ordering: .relaxed)
            _$simpleRegistrar.triggerDidChange(for: \.lastActivity, on: self)
        }
    }


    @SpeziBluetooth var services: [GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.services, on: self)
        }
    }

    @inlinable var name: String? {
        access(keyPath: \._peripheralName)
        access(keyPath: \._advertisementData)
        return lock.withReadLock {
            _peripheralName ?? _advertisementData.localName
        }
    }

    @inlinable var readOnlyRssi: Int {
        access(keyPath: \._rssi)
        return _rssi.load(ordering: .relaxed)
    }

    @inlinable var readOnlyState: PeripheralState {
        access(keyPath: \._state)
        return _state.load(ordering: .relaxed)
    }

    @inlinable var readOnlyNearby: Bool {
        access(keyPath: \._nearby)
        return _nearby.load(ordering: .relaxed)
    }

    @inlinable var readOnlyAdvertisementData: AdvertisementData {
        access(keyPath: \._advertisementData)
        return lock.withReadLock {
            _advertisementData
        }
    }

    var readOnlyLastActivity: Date {
        let timeIntervalSince1970 = Double(bitPattern: _lastActivityTimeIntervalSince1970BitPattern.load(ordering: .relaxed))
        return Date(timeIntervalSince1970: timeIntervalSince1970)
    }

    @SpeziBluetooth var peripheralName: String? {
        get {
            access(keyPath: \._peripheralName)
            return lock.withReadLock {
                _peripheralName
            }
        }
        set {
            let didChange = newValue != _peripheralName
            withMutation(keyPath: \._peripheralName) {
                lock.withWriteLock {
                    _peripheralName = newValue
                }
            }

            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.peripheralName, on: self)
            }
        }
    }

    @SpeziBluetooth var rssi: Int {
        get {
            readOnlyRssi
        }
        set {
            let didChange = newValue != readOnlyRssi
            withMutation(keyPath: \._rssi) {
                _rssi.store(newValue, ordering: .relaxed)
            }
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.rssi, on: self)
            }
        }
    }

    @SpeziBluetooth var advertisementData: AdvertisementData {
        get {
            readOnlyAdvertisementData
        }
        set {
            let didChange = newValue != _advertisementData
            withMutation(keyPath: \._advertisementData) {
                lock.withWriteLock {
                    _advertisementData = newValue
                }
            }

            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.advertisementData, on: self)
            }
        }
    }

    @SpeziBluetooth var state: PeripheralState {
        get {
            readOnlyState
        }
        set {
            let didChange = newValue != readOnlyState
            withMutation(keyPath: \._state) {
                _state.store(newValue, ordering: .relaxed)
            }
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.state, on: self)
            }
        }
    }

    @SpeziBluetooth var nearby: Bool {
        get {
            readOnlyNearby
        }
        set {
            let didChange = newValue != readOnlyNearby
            withMutation(keyPath: \._nearby) {
                _nearby.store(newValue, ordering: .relaxed)
            }

            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.nearby, on: self)
            }
        }
    }

    // swiftlint:disable:next identifier_name
    @ObservationIgnored let _$simpleRegistrar = ValueObservationRegistrar<PeripheralStorage>()

    init(peripheralName: String?, rssi: Int, advertisementData: AdvertisementData, state: PeripheralState, lastActivity: Date = .now) {
        self._peripheralName = peripheralName
        self._advertisementData = advertisementData
        self._rssi = ManagedAtomic(rssi)
        self._state = ManagedAtomic(state)
        self._nearby = ManagedAtomic(false)
        self._lastActivity = lastActivity
        self._lastActivityTimeIntervalSince1970BitPattern = ManagedAtomic(lastActivity.timeIntervalSince1970.bitPattern)
    }

    @SpeziBluetooth
    func update(state: PeripheralState) {
        let current = self.state
        if current != state {
            // we set connected on our own! See `signalFullyDiscovered`
            if !(current == .connecting && state == .connected) {
                self.state = state
            }
        }

        if current == .connecting || current == .connected {
            self.nearby = true
        }
    }

    @SpeziBluetooth
    func signalFullyDiscovered() {
        if state == .connecting {
            state = .connected
            update(state: .connected) // ensure other logic is called as well
        }
    }
}
