//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


protocol KVOReceiver: AnyObject {
    func observeChange<K, V: Sendable>(of keyPath: KeyPath<K, V> & Sendable, value: V) async
}


final class KVOStateObserver<Receiver: KVOReceiver>: NSObject, Sendable {
    // reference counting is atomic, so non-isolated unsafe is fine (as long as we don't mutate)
    private nonisolated(unsafe) weak var receiver: Receiver?

    // we never mutate, but has to be var, as we weakly capture self in this property
    private nonisolated(unsafe) var observation: NSKeyValueObservation?

    // swiftlint:disable:next function_default_parameter_at_end
    init<Entity: NSObject, V>(receiver: Receiver? = nil, entity: Entity, property: KeyPath<Entity, V> & Sendable) where V: Sendable {
        self.receiver = receiver
        super.init()

        observation = entity.observe(property) { [weak self] entity, _ in
            let value = entity[keyPath: property]
            self?.observeChange(of: property, value: value)
        }
    }

    func initReceiver(_ receiver: Receiver) {
        self.receiver = receiver
    }

    func observeChange<K, V: Sendable>(of keyPath: KeyPath<K, V> & Sendable, value: V) {
        Task { @SpeziBluetooth in
            await receiver?.observeChange(of: keyPath, value: value)
        }
    }
}
