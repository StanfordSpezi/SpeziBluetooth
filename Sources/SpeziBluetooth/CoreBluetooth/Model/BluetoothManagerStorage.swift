//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import Foundation
import OrderedCollections


@Observable
final class BluetoothManagerStorage: ValueObservable, Sendable {
    private let _isScanning = ManagedAtomic<Bool>(false)
    private let _state = ManagedAtomic<BluetoothState>(.unknown)

    @ObservationIgnored private nonisolated(unsafe) var _discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> = [:]
    private let rwLock = RWLock()

    @SpeziBluetooth var retrievedPeripherals: OrderedDictionary<UUID, WeakReference<BluetoothPeripheral>> = [:] {
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.retrievedPeripherals, on: self)
        }
    }
    @SpeziBluetooth @ObservationIgnored private var subscribedContinuations: [UUID: AsyncStream<BluetoothState>.Continuation] = [:]

    /// Note: we track, based on the CoreBluetooth reported connected state.
    @SpeziBluetooth var connectedDevices: Set<UUID> = []
    @MainActor private(set) var maHasConnectedDevices: Bool = false // we need a main actor isolated one for efficient SwiftUI support.

    @SpeziBluetooth var hasConnectedDevices: Bool {
        !connectedDevices.isEmpty
    }

    @inlinable var readOnlyState: BluetoothState {
        access(keyPath: \._state)
        return _state.load(ordering: .relaxed)
    }

    @inlinable var readOnlyIsScanning: Bool {
        access(keyPath: \._isScanning)
        return _isScanning.load(ordering: .relaxed)
    }

    @inlinable var readOnlyDiscoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        access(keyPath: \._discoveredPeripherals)
        return rwLock.withReadLock {
            _discoveredPeripherals
        }
    }

    @SpeziBluetooth var state: BluetoothState {
        get {
            readOnlyState
        }
        set {
            withMutation(keyPath: \._state) {
                _state.store(newValue, ordering: .relaxed)
            }
            _$simpleRegistrar.triggerDidChange(for: \.state, on: self)

            for continuation in subscribedContinuations.values {
                continuation.yield(state)
            }
        }
    }

    @SpeziBluetooth var isScanning: Bool {
        get {
            readOnlyIsScanning
        }
        set {
            withMutation(keyPath: \._isScanning) {
                _isScanning.store(newValue, ordering: .relaxed)
            }
            _$simpleRegistrar.triggerDidChange(for: \.isScanning, on: self) // didSet
        }
    }

    @SpeziBluetooth var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        get {
            readOnlyDiscoveredPeripherals
        }
        set {
            withMutation(keyPath: \._discoveredPeripherals) {
                rwLock.withReadLock {
                    _discoveredPeripherals = newValue
                }
            }
            _$simpleRegistrar.triggerDidChange(for: \.discoveredPeripherals, on: self) // didSet
        }
    }

    // swiftlint:disable:next identifier_name
    @ObservationIgnored let _$simpleRegistrar = ValueObservationRegistrar<BluetoothManagerStorage>()

    init() {}


    @SpeziBluetooth
    func update(state: BluetoothState) {
        self.state = state
    }

    @SpeziBluetooth
    func subscribe(_ continuation: AsyncStream<BluetoothState>.Continuation) -> UUID {
        let id = UUID()
        subscribedContinuations[id] = continuation
        return id
    }

    @SpeziBluetooth
    func unsubscribe(for id: UUID) {
        subscribedContinuations[id] = nil
    }

    @SpeziBluetooth
    func cbDelegateSignal(connected: Bool, for id: UUID) async {
        if connected {
            connectedDevices.insert(id)
        } else {
            connectedDevices.remove(id)
        }
        await updateMainActorConnectedDevices(hasConnectedDevices: !connectedDevices.isEmpty)
    }

    @MainActor
    private func updateMainActorConnectedDevices(hasConnectedDevices: Bool) {
        maHasConnectedDevices = hasConnectedDevices
    }


    deinit {
        Task { @SpeziBluetooth [subscribedContinuations] in
            for continuation in subscribedContinuations.values {
                continuation.finish()
            }
        }
    }
}


extension BluetoothManagerStorage {
    var stateSubscription: AsyncStream<BluetoothState> {
        AsyncStream(BluetoothState.self) { continuation in
            Task { @SpeziBluetooth in
                let id = subscribe(continuation)
                continuation.onTermination = { @Sendable [weak self] _ in
                    guard let self = self else {
                        return
                    }
                    Task.detached { @SpeziBluetooth in
                        self.unsubscribe(for: id)
                    }
                }
            }
        }
    }
}
