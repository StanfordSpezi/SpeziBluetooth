//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OrderedCollections


@SpeziBluetooth
final class ChangeSubscriptions<Value: Sendable>: Sendable {
    private struct Registration: Sendable {
        let subscription: AsyncStream<Value>
        let id: UUID
    }

    private var continuations: OrderedDictionary<UUID, AsyncStream<Value>.Continuation> = [:]

    nonisolated init() {}

    func notifySubscribers(with value: Value, ignoring: Set<UUID> = []) {
        for (id, continuation) in continuations where !ignoring.contains(id) {
            continuation.yield(value)
        }
    }

    func notifySubscriber(id: UUID, with value: Value) {
        continuations[id]?.yield(value)
    }

    private nonisolated  func _newSubscription() -> Registration {
        let id = UUID()
        let stream = AsyncStream { continuation in
            Task.detached { @SpeziBluetooth in
                self.continuations[id] = continuation

                continuation.onTermination = { [weak self] _ in
                    guard let self else {
                        return
                    }

                    Task { @SpeziBluetooth in
                        self.continuations.removeValue(forKey: id)
                    }
                }
            }
        }

        return Registration(subscription: stream, id: id)
    }

    nonisolated func newSubscription() -> AsyncStream<Value> {
        _newSubscription().subscription
    }

    @discardableResult
    nonisolated func newOnChangeSubscription(perform action: @escaping @Sendable (_ oldValue: Value, _ newValue: Value) async -> Void) -> UUID {
        let registration = _newSubscription()

        // It's important to use a detached Task here.
        // Otherwise it might inherit TaskLocal values which might include Spezi moduleInitContext
        // which would create a strong reference to the device.
        Task.detached { @SpeziBluetooth [weak self] in
            var currentValue: Value?

            for await element in registration.subscription {
                guard self != nil else {
                    return
                }

                await action(currentValue ?? element, element)
                currentValue = element
            }
        }

        // There is no need to save this Task handle (makes it easier for use as we are in an non-isolated context right here).
        // The task will automatically cleanup itself, once it the AsyncStream is getting cancelled/finished.

        return registration.id
    }

    deinit {
        for continuation in continuations.values {
            continuation.finish()
        }

        continuations.removeAll()
    }
}
