//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OrderedCollections


class ChangeSubscriptions<Value>: @unchecked Sendable {
    private struct Registration {
        let subscription: AsyncStream<Value>
        let id: UUID
    }

    private actor Dispatch: BluetoothActor {
        let bluetoothQueue: DispatchSerialQueue

        init(_ bluetoothQueue: DispatchSerialQueue) {
            self.bluetoothQueue = bluetoothQueue
        }
    }

    private let dispatch: Dispatch
    private var continuations: OrderedDictionary<UUID, AsyncStream<Value>.Continuation> = [:]
    private var taskHandles: [UUID: Task<Void, Never>] = [:]
    private let lock = NSLock()

    init(queue: DispatchSerialQueue) {
        self.dispatch = Dispatch(queue)
    }

    func notifySubscribers(with value: Value, ignoring: Set<UUID> = []) {
        for (id, continuation) in continuations where !ignoring.contains(id) {
            continuation.yield(value)
        }
    }

    private func _newSubscription() -> Registration {
        let id = UUID()
        let stream = AsyncStream { continuation in
            self.lock.withLock {
                self.continuations[id] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else {
                    return
                }

                lock.withLock {
                    _ = self.continuations.removeValue(forKey: id)
                }
            }
        }

        return Registration(subscription: stream, id: id)
    }

    func newSubscription() -> AsyncStream<Value> {
        _newSubscription().subscription
    }

    @discardableResult
    func newOnChangeSubscription(perform action: @escaping (Value) async -> Void) -> UUID {
        let registration = _newSubscription()

        // It's important to use a detached Task here.
        // Otherwise it might inherit TaskLocal values which might include Spezi moduleInitContext
        // which would create a strong reference to the device.
        let task = Task.detached { @SpeziBluetooth [weak self, dispatch] in
            for await element in registration.subscription {
                guard self != nil else {
                    return
                }

                await dispatch.isolated { _ in
                    await action(element)
                }
            }

            self?.lock.withLock {
                _ = self?.taskHandles.removeValue(forKey: registration.id)
            }
        }

        lock.withLock {
            taskHandles[registration.id] = task
        }

        return registration.id
    }

    deinit {
        lock.withLock {
            for continuation in continuations.values {
                continuation.finish()
            }

            for task in taskHandles.values {
                task.cancel()
            }

            continuations.removeAll()
            taskHandles.removeAll()
        }
    }
}
