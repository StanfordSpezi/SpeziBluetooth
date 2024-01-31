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
        let closure: (Value) async -> Void
    }

    // task local value ensures nobody is interfering here and resolves thread safety
    @TaskLocal static var instance: ClosureRegistrar?


    private var registrations: [ObjectIdentifier: Any] = [:]

    init() {}

    func insert<Value>(for object: ObjectIdentifier, closure: @escaping (Value) async -> Void) {
        registrations[object] = Entry(closure: closure)
    }

    func retrieve<Value>(for object: ObjectIdentifier, value: Value.Type = Value.self) -> ((Value) async -> Void)? {
        guard let optionalEntry = registrations[object],
              let entry = optionalEntry as? Entry<Value> else {
            return nil
        }
        return entry.closure
    }
}
