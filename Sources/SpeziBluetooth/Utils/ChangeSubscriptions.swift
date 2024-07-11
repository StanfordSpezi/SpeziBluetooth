//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OrderedCollections


final class ChangeSubscriptions<Value: Sendable>: Sendable {
    private struct Registration: Sendable {
        let subscription: AsyncStream<Value>
        let id: UUID
    }

    private nonisolated(unsafe) var continuations: OrderedDictionary<UUID, AsyncStream<Value>.Continuation> = [:]
    private nonisolated(unsafe) var taskHandles: [UUID: Task<Void, Never>] = [:]
    private let lock = NSLock() // protects both non-isolated unsafe vars above

    init() {}

    func notifySubscribers(with value: Value, ignoring: Set<UUID> = []) {
        for (id, continuation) in continuations where !ignoring.contains(id) {
            continuation.yield(value)
        }
    }

    func notifySubscriber(id: UUID, with value: Value) {
        continuations[id]?.yield(value)
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
    func newOnChangeSubscription(perform action: @escaping @Sendable (_ oldValue: Value, _ newValue: Value) async -> Void) -> UUID {
        let registration = _newSubscription()

        // It's important to use a detached Task here.
        // Otherwise it might inherit TaskLocal values which might include Spezi moduleInitContext
        // which would create a strong reference to the device.
        let task = Task.detached { @SpeziBluetooth [weak self] in
            var currentValue: Value?

            for await element in registration.subscription {
                guard self != nil else {
                    return
                }

                await SpeziBluetooth.run {
                    await action(currentValue ?? element, element)
                }
                currentValue = element
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
