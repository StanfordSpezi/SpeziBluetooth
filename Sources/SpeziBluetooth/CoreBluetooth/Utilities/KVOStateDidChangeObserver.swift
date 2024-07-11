//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


@SpeziBluetooth
final class KVOStateDidChangeObserver<Entity: NSObject, Value>: NSObject, Sendable {
    // we never mutate, but has to be var, as we weakly capture self in this property
    private nonisolated(unsafe) var observation: NSKeyValueObservation?

    private let entity: Entity
    private let keyPath: KeyPath<Entity, Value>

    @SpeziBluetooth
    init(entity: Entity, property: KeyPath<Entity, Value>, perform action: @SpeziBluetooth @Sendable @escaping (Value) async -> Void) {
        self.entity = entity
        self.keyPath = property
        super.init()

        observation = entity.observe(property) { [weak self] _, _ in
            Task { @SpeziBluetooth [weak self] in
                guard let self else {
                    return
                }
                let value = self.entity[keyPath: self.keyPath]
                await action(value)
            }
        }
    }
}
