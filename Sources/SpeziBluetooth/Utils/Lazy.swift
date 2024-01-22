//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


@propertyWrapper
class Lazy<Value> {
    private let initializer: () -> Value
    private let onCleanup: () -> Void

    private var storedValue: Value?


    var wrappedValue: Value {
        if let storedValue {
            return storedValue
        }

        let value = initializer()
        storedValue = value
        return value
    }


    /// Support lazy initialization of lazy property.
    convenience init() {
        self.init {
            preconditionFailure("Forgot to initialize \(Self.self) lazy property!")
        }
    }


    init(initializer: @escaping () -> Value, onCleanup: @escaping () -> Void = {}) {
        self.initializer = initializer
        self.onCleanup = onCleanup
    }


    func destroy() {
        let wasStored = storedValue != nil
        storedValue = nil
        if wasStored {
            onCleanup()
        }
    }
}
