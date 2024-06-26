//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation
import Spezi
import SpeziFoundation


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


extension Box where Value: AnyOptional, Value.Wrapped: DefaultInitializable {
    var valueOrInitialize: Value.Wrapped {
        get {
            if let value = value.unwrappedOptional {
                return value
            }

            let wrapped = Value.Wrapped()
            value = wrappedToValue(wrapped)
            return wrapped
        }
        _modify {
            if var value = value.unwrappedOptional {
                yield &value
                self.value = wrappedToValue(value)
                return
            }

            var wrapped = Value.Wrapped()
            yield &wrapped
            self.value = wrappedToValue(wrapped)
        }
        set {
            value = wrappedToValue(newValue)
        }
    }

    private func wrappedToValue(_ value: Value.Wrapped) -> Value {
        guard let newValue = Optional.some(value) as? Value else {
            preconditionFailure("Value of \(Optional<Value.Wrapped>.self) was not equal to \(Value.self).")
        }
        return newValue
    }
}
