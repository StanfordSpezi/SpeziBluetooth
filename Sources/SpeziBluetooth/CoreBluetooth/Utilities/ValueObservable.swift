//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


protocol AnyObservation {}

// TODO: calling that ValueObservation/ValueObservable!
struct SimpleObservationRegistrar<Observable: SimpleObservable> {
    struct Observation<Value>: AnyObservation {
        let keyPath: KeyPath<Observable, Value>
        let handler: (Value) -> Void
    }

    private var id: UInt64 = 0
    private var observations: [UInt64: AnyObservation] = [:]
    private var keyPathIndex: [AnyKeyPath: Set<UInt64>] = [:]

    private mutating func nextId() -> UInt64 {
        defer {
            id &+= 1 // add with overflow operator
        }
        return id
    }

    mutating func onChange<Value>(of keyPath: KeyPath<Observable, Value>, perform closure: @escaping (Value) -> Void) {
        let id = nextId()
        observations[id] = Observation(keyPath: keyPath, handler: closure)
        keyPathIndex[keyPath, default: []].insert(id)
    }

    mutating func triggerDidChange<Value>(for keyPath: KeyPath<Observable, Value>, on observable: Observable) {
        guard let ids = keyPathIndex.removeValue(forKey: keyPath) else {
            return
        }

        for id in ids {
            guard let anyObservation = observations.removeValue(forKey: id),
                  let observation = anyObservation as? Observation<Value> else {
                continue
            }

            let value = observable[keyPath: keyPath]
            observation.handler(value)
        }
    }
}

// TODO: rename
protocol SimpleObservable: AnyObject {
    var _$simpleRegistrar: SimpleObservationRegistrar<Self> { get set }

    func onChange<Value>(of keyPath: KeyPath<Self, Value>, perform closure: @escaping (Value) -> Void)
}

extension SimpleObservable {
    func onChange<Value>(of keyPath: KeyPath<Self, Value>, perform closure: @escaping (Value) -> Void) {
        _$simpleRegistrar.onChange(of: keyPath, perform: closure)
    }
}
