//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Tracking notification closure registrations for ``Characteristic`` when peripheral is not available yet.
final class ClosureRegistrar {
    struct Entry<Value> {
        let closure: OnChangeClosure<Value>
    }

    // task local value ensures nobody is interfering here and resolves thread safety
    // we maintain two different states for different processes (init vs. setup).
    @TaskLocal static var writeableView: ClosureRegistrar?
    @TaskLocal static var readableView: ClosureRegistrar?


    private var registrations: [ObjectIdentifier: Any] = [:]

    init() {}

    func insert<Value>(for object: ObjectIdentifier, closure: OnChangeClosure<Value>) {
        registrations[object] = Entry(closure: closure)
    }

    func retrieve<Value>(for object: ObjectIdentifier, value: Value.Type = Value.self) -> OnChangeClosure<Value>? {
        guard let optionalEntry = registrations[object],
              let entry = optionalEntry as? Entry<Value> else {
            return nil
        }
        return entry.closure
    }
}
