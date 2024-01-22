//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


protocol KVOReceiver: AnyObject {
    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) async
}


class KVOStateObserver<Receiver: KVOReceiver>: NSObject {
    private weak var receiver: Receiver?

    private var observation: NSKeyValueObservation?

    // swiftlint:disable:next function_default_parameter_at_end
    init<Entity: NSObject, V>(receiver: Receiver? = nil, entity: Entity, property: KeyPath<Entity, V>) {
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

    func observeChange<K, V>(of keyPath: KeyPath<K, V>, value: V) {
        Task {
            await receiver?.observeChange(of: keyPath, value: value)
        }
    }
}
