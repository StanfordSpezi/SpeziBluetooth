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
final class BluetoothManagerStorage: ValueObservable, Sendable {
    // swiftlint:disable identifier_name
    private(set) nonisolated(unsafe) var _isScanning = false
    private(set) nonisolated(unsafe) var _state: BluetoothState = .unknown

    private(set) nonisolated(unsafe) var _discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> = [:]
    private(set) nonisolated(unsafe) var _retrievedPeripherals: OrderedDictionary<UUID, WeakReference<BluetoothPeripheral>> = [:]
    // swiftlint:enable identifier_name

    @SpeziBluetooth private var subscribedContinuations: [UUID: AsyncStream<BluetoothState>.Continuation] = [:]

    @SpeziBluetooth var state: BluetoothState {
        get {
            _state
        }
        set {
            _state = newValue
            _$simpleRegistrar.triggerDidChange(for: \.state, on: self)

            for continuation in subscribedContinuations.values {
                continuation.yield(state)
            }
        }
    }

    @SpeziBluetooth var isScanning: Bool {
        get {
            _isScanning
        }
        set {
            _isScanning = newValue
            _$simpleRegistrar.triggerDidChange(for: \.isScanning, on: self) // didSet
        }
    }

    @SpeziBluetooth var discoveredPeripherals: OrderedDictionary<UUID, BluetoothPeripheral> {
        get {
            _discoveredPeripherals
        }
        _modify {
            yield &_discoveredPeripherals
            _$simpleRegistrar.triggerDidChange(for: \.discoveredPeripherals, on: self) // didSet
        }
        set {
            _discoveredPeripherals = newValue
            _$simpleRegistrar.triggerDidChange(for: \.discoveredPeripherals, on: self) // didSet
        }
    }

    @SpeziBluetooth var retrievedPeripherals: OrderedDictionary<UUID, WeakReference<BluetoothPeripheral>> {
        get {
            _retrievedPeripherals
        }
        _modify {
            yield &_retrievedPeripherals
            _$simpleRegistrar.triggerDidChange(for: \.retrievedPeripherals, on: self)
        }
        set {
            _retrievedPeripherals = newValue
            _$simpleRegistrar.triggerDidChange(for: \.retrievedPeripherals, on: self)
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


    deinit {
        Task { @SpeziBluetooth [_subscribedContinuations] in
            for continuation in _subscribedContinuations.values {
                continuation.finish()
            }
        }
    }
}
