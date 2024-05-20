//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// A onChange closure instance.
struct OnChangeClosure<Value> {
    /// The initial flag indicates if the closure should be called with the initial value
    /// or strictly only if the value changes.
    let initial: Bool
    private let closure: (Value) async -> Void


    init(initial: Bool, closure: @escaping (Value) async -> Void) {
        self.initial = initial
        self.closure = closure
    }


    func callAsFunction(_ value: Value) async {
        await closure(value)
    }
}


/// State model for an onChange closure property.
enum ChangeClosureState<Value> {
    /// The is no onChange closure registered.
    case none
    /// The onChange closure value.
    case value(OnChangeClosure<Value>)
    /// The onChange closure was cleared (e.g., upon a disconnect).
    /// This signals that there must not be any new onChange closure registrations to avoid reference cycles.
    case cleared
}
