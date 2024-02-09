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
    public func onChange(perform: @escaping (Value) async -> Void) {
        guard let injection else {
            guard let closures = ClosureRegistrar.writeableView else {
                Bluetooth.logger.warning(
                    """
                    Tried to register onChange(perform:) closure out-of-band. Make sure to register your onChange closure \
                    within the initializer or when the peripheral is fully injected. This is expected if you manually initialized your device. \
                    The closure was discarded and won't have any effect.
                    """
                )
                return
            }
            // Similar to CharacteristicAccessor/onChange(perform:), we save it in a global registrar
            // to avoid reference cycles we can't control.
            closures.insert(for: id, closure: perform)
            return
        }

        // global actor ensures these tasks are queued serially and are executed in order.
        Task { @SpeziBluetooth in
            await injection.setOnChangeClosure(perform)
        }
    }
}
