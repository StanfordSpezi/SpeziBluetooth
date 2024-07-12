//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


@propertyWrapper
@SpeziBluetooth
final class Lazy<Value>: Sendable {
    private var initializer: (() -> Value)?
    private var onCleanup: (() -> Void)?

    private var storedValue: Value?


    var wrappedValue: Value {
        if let storedValue {
            return storedValue
        }

        guard let initializer else {
            preconditionFailure("Forgot to initialize \(Self.self) lazy property!")
        }

        let value = initializer()
        storedValue = value
        return value
    }


    var isInitialized: Bool {
        storedValue != nil
    }

    /// Support lazy initialization of lazy property.
    nonisolated init() {}


    init(initializer: @escaping () -> Value, onCleanup: @escaping () -> Void = {}) {
        self.initializer = initializer
        self.onCleanup = onCleanup
    }

    func supply(initializer: @escaping () -> Value, onCleanup: @escaping () -> Void = {}) {
        self.initializer = initializer
        self.onCleanup = onCleanup
    }


    func destroy() {
        let wasStored = storedValue != nil
        storedValue = nil
        if wasStored, let onCleanup {
            onCleanup()
        }
    }
}
