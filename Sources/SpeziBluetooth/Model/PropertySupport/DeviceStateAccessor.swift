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
/// - ``onChange(initial:perform:)-8x9cj``
/// - ``onChange(initial:perform:)-9igc9``
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
}


extension DeviceStateAccessor {
    /// Retrieve a subscription to changes to the device state.
    ///
    /// This property creates an AsyncStream that yields all future updates to the device state.
    public var subscription: AsyncStream<Value> {
        guard let injection else {
            preconditionFailure(
                "The `subscription` of a @DeviceState cannot be accessed within the initializer. Defer access to the `configure() method"
            )
        }
        return injection.newSubscription()
    }

    /// Perform action whenever the state value changes.
    ///
    /// Register a change handler with the device state that is called every time the value changes.
    ///
    /// - Note: `onChange` handlers are bound to the lifetime of the device. If you need to control the lifetime yourself refer to using ``subscription``.
    ///
    /// Note that you cannot set up onChange handlers within the initializers.
    /// Use the [`configure()`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module/configure()-5pa83) to set up
    /// all your handlers.
    /// - Important: You must capture `self` weakly only. Capturing `self` strongly causes a memory leak.
    ///
    /// - Note: This closure is called from the Bluetooth Serial Executor, if you don't pass in an async method
    ///     that has an annotated actor isolation (e.g., `@MainActor` or actor isolated methods).
    ///
    /// - Parameters:
    ///     - initial: Whether the action should be run with the initial state value. Otherwise, the action will only run
    ///     strictly if the value changes.
    ///     - action: The change handler to register.
    public func onChange(initial: Bool = false, perform action: @escaping (Value) async -> Void) {
        onChange(initial: true) { _, newValue in
            await action(newValue)
        }
    }

    /// Perform action whenever the state value changes.
    ///
    /// Register a change handler with the device state that is called every time the value changes.
    ///
    /// - Note: `onChange` handlers are bound to the lifetime of the device. If you need to control the lifetime yourself refer to using ``subscription``.
    ///
    /// Note that you cannot set up onChange handlers within the initializers.
    /// Use the [`configure()`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module/configure()-5pa83) to set up
    /// all your handlers.
    /// - Important: You must capture `self` weakly only. Capturing `self` strongly causes a memory leak.
    ///
    /// - Note: This closure is called from the Bluetooth Serial Executor, if you don't pass in an async method
    ///     that has an annotated actor isolation (e.g., `@MainActor` or actor isolated methods).
    ///
    /// - Parameters:
    ///     - initial: Whether the action should be run with the initial state value. Otherwise, the action will only run
    ///     strictly if the value changes.
    ///     - action: The change handler to register, receiving both the old and new value.
    public func onChange(initial: Bool = false, perform action: @escaping (_ oldValue: Value, _ newValue: Value) async -> Void) {
        guard let injection else {
            preconditionFailure(
                """
                Register onChange(perform:) inside the initializer is not supported anymore. \
                Further, they no longer support capturing `self` without causing a memory leak. \
                Please migrate your code to register onChange listeners in the `configure()` method and make sure to weakly capture self.

                func configure() {
                    $state.onChange { [weak self] value in
                        self?.handleStateChange(value)
                    }
                }
                """
            )
        }

        injection.newOnChangeSubscription(initial: initial, perform: action)
    }
}


extension DeviceStateAccessor: @unchecked Sendable {}


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
