//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Tracking notification closure registrations for ``Characteristic`` when peripheral is not available yet.
final class NotificationRegistrar {
    struct Entry<Value> {
        let closure: (Value) -> Void
    }

    // task local value ensures nobody is interfering here and resolves thread safety
    @TaskLocal static var instance: NotificationRegistrar?


    private var registrations: [ObjectIdentifier: Any] = [:]

    init() {}

    func insert<Value>(for configuration: Characteristic<Value>.Configuration, closure: @escaping (Value) -> Void) {
        registrations[configuration.objectId] = Entry(closure: closure)
    }

    func retrieve<Value>(for configuration: Characteristic<Value>.Configuration) -> ((Value) -> Void)? {
        guard let optionalEntry = registrations[configuration.objectId],
              let entry = optionalEntry as? Entry<Value> else {
            return nil
        }
        return entry.closure
    }
}


extension Characteristic.Configuration {
    /// Memory address as an identifier for this Characteristic instance.
    fileprivate var objectId: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}
