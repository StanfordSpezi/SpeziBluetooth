//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import CoreBluetooth


struct CharacteristicTestInjections<Value> {
    var writeClosure: ((Value, WriteType) async throws -> Void)?
    var readClosure: (() async throws -> Value)?
    var requestClosure: ((Value) async throws -> Value)?
}


/// Interact with a given Characteristic.
///
/// This type allows you to interact with a Characteristic you previously declared using the ``Characteristic`` property wrapper.
///
/// - Note: The accessor captures the characteristic instance upon creation. Within the same `CharacteristicAccessor` instance
///     the view on the characteristic is consistent (characteristic exists vs. it doesn't, the underlying values themselves might still change).
///     However, if you project a new `CharacteristicAccessor` instance right after your access,
///     the view on the characteristic might have changed due to the asynchronous nature of SpeziBluetooth.
///
/// ## Topics
///
/// ### Characteristic properties
/// - ``isPresent``
/// - ``properties``
/// - ``descriptors``
///
/// ### Reading a value
/// - ``read()``
///
/// ### Writing a value
/// - ``write(_:)``
/// - ``writeWithoutResponse(_:)``
///
/// ### Controlling notifications
/// - ``isNotifying``
/// - ``enableNotifications(_:)``
///
/// ### Get notified about changes
/// - ``onChange(initial:perform:)``
///
/// ### Control Point Characteristics
/// - ``sendRequest(_:timeout:)``
public struct CharacteristicAccessor<Value> {
    let configuration: Characteristic<Value>.Configuration
    let injection: CharacteristicPeripheralInjection<Value>?
    /// Capture of the characteristic.
    private let characteristic: GATTCharacteristic?

    /// We keep track of this for testing support.
    private let _value: ObservableBox<Value?>
    /// Closure that captures write for testing support.
    private let _testInjections: Box<CharacteristicTestInjections<Value>>


    init(
        configuration: Characteristic<Value>.Configuration,
        injection: CharacteristicPeripheralInjection<Value>?,
        value: ObservableBox<Value?>,
        testInjections: Box<CharacteristicTestInjections<Value>>
    ) {
        self.configuration = configuration
        self.injection = injection
        self.characteristic = injection?.unsafeCharacteristic

        self._value = value
        self._testInjections = testInjections
    }
}


extension CharacteristicAccessor: @unchecked Sendable {}


extension CharacteristicAccessor {
    /// Determine if the characteristic is available.
    ///
    /// Returns `true` if the characteristic is available for the current device.
    /// It is `true` if (a) the device is connected and (b) the device exposes the requested characteristic.
    public var isPresent: Bool {
        characteristic != nil
    }

    /// Properties of the characteristic.
    ///
    /// `nil` if device is not connected.
    public var properties: CBCharacteristicProperties? {
        characteristic?.properties
    }

    /// Descriptors of the characteristic.
    ///
    /// `nil` if device is not connected or descriptors are not yet discovered.
    public var descriptors: [CBDescriptor]? { // swiftlint:disable:this discouraged_optional_collection
        characteristic?.descriptors
    }
}

// MARK: - Readable

extension CharacteristicAccessor where Value: ByteDecodable {
    /// Characteristic is currently notifying about updated values.
    ///
    /// This is also `false` if device is not connected.
    public var isNotifying: Bool {
        characteristic?.isNotifying ?? false
    }


    /// Retrieve a subscription to changes to the characteristic value.
    ///
    /// This property creates an AsyncStream that yields all future updates to the characteristic value.
    public var subscription: AsyncStream<Value> {
        guard let injection else {
            preconditionFailure(
                "The `subscription` of a @Characteristic cannot be accessed within the initializer. Defer access to the `configure() method"
            )
        }
        return injection.newSubscription()
    }


    /// Perform action whenever the characteristic value changes.
    ///
    /// Register a change handler with the characteristic that is called every time the value changes.
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
    ///     - initial: Whether the action should be run with the initial characteristic value.
    ///     Otherwise, the action will only run strictly if the value changes.
    ///     - action: The change handler to register.
    public func onChange(initial: Bool = false, @_implicitSelfCapture perform action: @escaping (Value) async -> Void) {
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


    /// Enable or disable characteristic notifications.
    /// - Parameter enabled: Flag indicating if notifications should be enabled.
    public func enableNotifications(_ enabled: Bool = true) async {
        guard let injection else {
            // this value will be populated to the injection once it is set up
            configuration.defaultNotify = enabled
            return
        }

        await injection.enableNotifications(enabled)
    }

    /// Read the current characteristic value from the remote peripheral.
    /// - Returns: The value that was read.
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    ///     It might also throw a ``BluetoothError/notPresent(service:characteristic:)`` or ``BluetoothError/incompatibleDataFormat`` error.
    @discardableResult
    public func read() async throws -> Value {
        if let injectedReadClosure = _testInjections.value.readClosure {
            return try await injectedReadClosure()
        }

        guard let injection  else {
            throw BluetoothError.notPresent(characteristic: configuration.id)
        }

        return try await injection.read()
    }
}

// MARK: - Writeable

extension CharacteristicAccessor where Value: ByteEncodable {
    /// Write the value of a characteristic expecting a confirmation.
    ///
    /// Writes the value of a characteristic expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.3 Write Characteristic Value.
    ///
    /// - Parameter value: The value you want to write.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    ///     It might also throw a ``BluetoothError/notPresent(service:characteristic:)`` error.
    public func write(_ value: Value) async throws {
        if let injectedWriteClosure = _testInjections.value.writeClosure {
            try await injectedWriteClosure(value, .withResponse)
            return
        }

        guard let injection else {
            throw BluetoothError.notPresent(characteristic: configuration.id)
        }

        try await injection.write(value)
    }

    /// Write the value of a characteristic without expecting a confirmation.
    ///
    /// Writes the value of a characteristic without expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.1 Write Without Response.
    /// - Parameter value: The value you want to write.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    ///     It might also throw a ``BluetoothError/notPresent(service:characteristic:)`` error.
    public func writeWithoutResponse(_ value: Value) async throws {
        if let injectedWriteClosure = _testInjections.value.writeClosure {
            try await injectedWriteClosure(value, .withoutResponse)
            return
        }

        guard let injection else {
            throw BluetoothError.notPresent(characteristic: configuration.id)
        }

        try await injection.writeWithoutResponse(value)
    }
}

// MARK: - Control Point

extension CharacteristicAccessor where Value: ControlPointCharacteristic {
    /// Send request to a control point characteristics and await the response.
    ///
    /// This method can be used with ``ControlPointCharacteristic`` to send a request and await the response of the peripheral.
    ///
    /// - Important: The response is delivered using a notification. In order to use this method you must enable notifications
    ///     for the characteristics (see ``enableNotifications(_:)``).
    ///
    /// - Parameters:
    ///     - value: The request you want to send.
    ///     - timeout: The timeout to wait to receive a response via notify or indicate.
    /// - Returns: The response returned from the peripheral.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    ///     It might also throw a ``BluetoothError/notPresent(service:characteristic:)``,
    ///     ``BluetoothError/controlPointRequiresNotifying(service:characteristic:)`` or
    ///     ``BluetoothError/controlPointInProgress(service:characteristic:)`` error.
    public func sendRequest(_ value: Value, timeout: Duration = .seconds(20)) async throws -> Value {
        if let injectedRequestClosure = _testInjections.value.requestClosure {
            return try await injectedRequestClosure(value)
        }

        guard let injection else {
            throw BluetoothError.notPresent(characteristic: configuration.id)
        }

        return try await injection.sendRequest(value, timeout: timeout)
    }
}

// MARK: - Testing Support

@_spi(TestingSupport)
extension CharacteristicAccessor {
    /// Inject a custom value for previewing purposes.
    ///
    /// This method can be used to inject a custom characteristic value.
    /// This is particularly helpful when writing SwiftUI previews or doing UI testing.
    ///
    /// - Note: `onChange` closures are currently not supported. If required, you should
    /// call your onChange closures manually.
    ///
    /// - Parameter value: The value to inject.
    public func inject(_ value: Value) {
        _value.value = value
    }

    /// Inject a custom action that sinks all write operations for testing purposes.
    ///
    /// This method can be used to inject a custom action that is called whenever a value is written to the characteristic.
    /// This is particularly helpful when writing unit tests to verify the value which was written to the characteristic.
    ///
    /// - Parameter action: The action to inject. Called for every write.
    public func onWrite(perform action: @escaping (Value, WriteType) async throws -> Void) {
        _testInjections.value.writeClosure = action
    }

    /// Inject a custom action that sinks all read operations for testing purposes.
    ///
    /// This method can be used to inject a custom action that is called whenever a value is read from the characteristic.
    /// This is particularly helpful when writing unit tests to return a custom value upon read requests.
    ///
    /// - Parameter action: The action to inject. Called for every read.
    public func onRead(return action: @escaping () async throws -> Value) {
        _testInjections.value.readClosure = action
    }

    /// Inject a custom action that sinks all control point request operations for testing purposes.
    ///
    /// This method can be used to inject a custom action that is called whenever a control point request is send to the characteristic.
    /// This is particularly helpful when writing unit test to validate the request payload and return a custom response payload.
    ///
    /// - Parameter action: The action to inject. Called for every control point request.
    public func onRequest(perform action: @escaping (Value) async throws -> Value) {
        _testInjections.value.requestClosure = action
    }
}
