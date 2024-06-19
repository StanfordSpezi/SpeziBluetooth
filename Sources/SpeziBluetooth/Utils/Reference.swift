//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


struct WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value? = nil) {
        self.value = value
    }
}
