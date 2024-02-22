//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


protocol AnyValueObservation {}


/// Internal value observation registrar.
///
/// Holds the registered closure till the next value update happens.
/// Inspired by Apple's Observation framework but with more power!
class ValueObservationRegistrar<Observable: ValueObservable> {
    struct ValueObservation<Value>: AnyValueObservation {
        let keyPath: KeyPath<Observable, Value>
        let handler: (Value) -> Void
    }

    private var id: UInt64 = 0
    private var observations: [UInt64: AnyValueObservation] = [:]
    private var keyPathIndex: [AnyKeyPath: Set<UInt64>] = [:]

    private func nextId() -> UInt64 {
        defer {
            id &+= 1 // add with overflow operator
        }
        return id
    }

    func onChange<Value>(of keyPath: KeyPath<Observable, Value>, perform closure: @escaping (Value) -> Void) {
        let id = nextId()
        observations[id] = ValueObservation(keyPath: keyPath, handler: closure)
        keyPathIndex[keyPath, default: []].insert(id)
    }

    func triggerDidChange<Value>(for keyPath: KeyPath<Observable, Value>, on observable: Observable) {
        guard let ids = keyPathIndex.removeValue(forKey: keyPath) else {
            return
        }

        for id in ids {
            guard let anyObservation = observations.removeValue(forKey: id),
                  let observation = anyObservation as? ValueObservation<Value> else {
                continue
            }

            let value = observable[keyPath: keyPath]
            observation.handler(value)
        }
    }
}


/// A model with value observable properties.
protocol ValueObservable: AnyObject {
    // swiftlint:disable:next identifier_name
    var _$simpleRegistrar: ValueObservationRegistrar<Self> { get set }

    func onChange<Value>(of keyPath: KeyPath<Self, Value>, perform closure: @escaping (Value) -> Void)
}


extension ValueObservable {
    func onChange<Value>(of keyPath: KeyPath<Self, Value>, perform closure: @escaping (Value) -> Void) {
        _$simpleRegistrar.onChange(of: keyPath, perform: closure)
    }
}
