//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Interact with a given device state.
///
/// This type allows you to interact with a device state you previously declared using the ``DeviceState`` property wrapper.
///
/// ## Topics
///
/// ### Get notified about changes
/// - ``onChange(perform:)``
public struct DeviceStateAccessor<Value> {
    private let id: ObjectIdentifier
    private let injection: DeviceStatePeripheralInjection<Value>?


    init(id: ObjectIdentifier, injection: DeviceStatePeripheralInjection<Value>?) {
        self.id = id
        self.injection = injection
    }


    /// Perform action whenever the state value changes.
    ///
    /// - Note: It is perfectly fine if you capture strongly self within your closure. The framework will
    ///     resolve any reference cycles for you.
    /// - Parameter perform: The change handler to register.
    public func onChange(perform: @escaping (Value) -> Void) {
        guard let injection else {
            // Similar to CharacteristicAccessor/onChange(perform:), we save it in a global registrar
            // to avoid reference cycles we can't control.
            ClosureRegistrar.instance?.insert(for: id, closure: perform)
            return
        }

        injection.setOnChangeClosure(perform)
    }
}
