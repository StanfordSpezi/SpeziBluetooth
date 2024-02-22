//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation


@Observable
class WeakObservableBox<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value? = nil) {
        self.value = value
    }
}


@Observable
class ObservableBox<Value> {
    var value: Value


    init(_ value: Value) {
        self.value = value
    }
}


class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
