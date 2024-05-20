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
    /// To support testing support.
    private let _injectedValue: ObservableBox<Value?>


    init(id: ObjectIdentifier, injection: DeviceStatePeripheralInjection<Value>?, injectedValue: ObservableBox<Value?>) {
        self.id = id
        self.injection = injection
        self._injectedValue = injectedValue
    }


    /// Perform action whenever the state value changes.
    ///
    /// - Important: This closure is called from the Bluetooth Serial Executor, if you don't pass in an async method
    ///     that has an annotated actor isolation (e.g., `@MainActor` or actor isolated methods).
    ///
    /// - Note: It is perfectly fine if you capture strongly self within your closure. The framework will
    ///     resolve any reference cycles for you.
    /// - Parameters:
    ///     - initial: Whether the action should be run with the initial state value. Otherwise, the action will only run
    ///     strictly if the value changes.
    ///     - action: The change handler to register.
    public func onChange(initial: Bool = false, perform action: @escaping (Value) async -> Void) {
        let closure = OnChangeClosure(initial: initial, closure: action)

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
            closures.insert(for: id, closure: closure)
            return
        }

        // global actor ensures these tasks are queued serially and are executed in order.
        Task { @SpeziBluetooth in
            await injection.setOnChangeClosure(closure)
        }
    }
}


// MARK: - Testing Support

@_spi(TestingSupport)
extension DeviceStateAccessor {
    /// Inject a custom value for previewing purposes.
    ///
    /// This method can be used to inject a custom device state value.
    /// This is particularly helpful when writing SwiftUI previews or doing UI testing.
    ///
    /// - Note: `onChange` closures are currently not supported. If required, you should
    /// call your onChange closures manually.
    ///
    /// - Parameter value: The value to inject.
    public func inject(_ value: Value) {
        _injectedValue.value = value
    }
}
