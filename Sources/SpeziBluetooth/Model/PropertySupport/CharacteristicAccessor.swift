//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// Interact with a given Characteristic.
///
/// This type allows you to interact with a Characteristic you previously declared using the ``Characteristic`` property wrapper.
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
/// - ``onChange(perform:)``
public struct CharacteristicAccessors<Value> {
    private let configuration: Characteristic<Value>.Configuration
    private let injection: CharacteristicPeripheralInjection<Value>?


    init(configuration: Characteristic<Value>.Configuration, injection: CharacteristicPeripheralInjection<Value>?) {
        self.configuration = configuration
        self.injection = injection
    }
}


extension CharacteristicAccessors {
    /// Determine if the characteristic is available.
    ///
    /// Returns true if the characteristic is available for the current device.
    /// It is true if (a) the device is connected and (b) the device exposes the requested characteristic.
    public var isPresent: Bool {
        injection?.characteristic != nil
    }

    /// Properties of the characteristic.
    ///
    /// Nil if device is not connected.
    public var properties: CBCharacteristicProperties? {
        injection?.characteristic?.properties
    }

    /// Descriptors of the characteristic.
    ///
    /// Nil if device is not connected or descriptors are not yet discovered.
    public var descriptors: [CBDescriptor]? { // swiftlint:disable:this discouraged_optional_collection
        injection?.characteristic?.descriptors
    }
}


extension CharacteristicAccessors where Value: ByteDecodable {
    /// Characteristic is currently notifying about updated values.
    ///
    /// This is also false if device is not connected.
    public var isNotifying: Bool {
        injection?.characteristic?.isNotifying ?? false
    }


    /// Perform action whenever the characteristic value changes.
    ///
    /// - Note: It is perfectly fine if you capture strongly self within your closure. The framework will
    ///     resolve any reference cycles for you.
    /// - Parameter perform: The change handler to register.
    public func onChange(perform: @escaping (Value) -> Void) {
        guard let injection else {
            // We save the instance in the global registrar if its available.
            // It will be available if we are instantiated through the Bluetooth module.
            // This indirection is required to support self referencing closures without encountering a strong reference cycle.
            ClosureRegistrar.instance?.insert(for: configuration.objectId, closure: perform)
            return
        }

        injection.setOnChangeClosure(perform)
    }


    /// Enable or disable characteristic notifications.
    /// - Parameter enabled: Flag indicating if notifications should be enabled.
    public func enableNotifications(_ enabled: Bool = true) async {
        guard let injection else {
            // this will value will be populated to the injection once it is set up
            configuration.defaultNotify = enabled
            return
        }

        await injection.enableNotifications(enabled)
    }

    /// Read the current characteristic value from the remote peripheral.
    /// - Returns: The value that was read.
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    ///     It might also throw a ``BluetoothError/notPresent`` or ``BluetoothError/incompatibleDataFormat`` error.
    @discardableResult
    public func read() async throws -> Value {
        guard let injection,
            let characteristic = injection.characteristic else {
            throw BluetoothError.notPresent(service: injection?.serviceId, characteristic: configuration.id)
        }

        let data = try await injection.peripheral.read(characteristic: characteristic)
        guard let value = Value(data: data) else {
            throw BluetoothError.incompatibleDataFormat
        }
        return value
    }
}


extension CharacteristicAccessors where Value: ByteEncodable {
    /// Write the value of a characteristic expecting a confirmation.
    ///
    /// Writes the value of a characteristic expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.3 Write Characteristic Value.
    ///
    /// - Parameter value: The value you want to write.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    ///     It might also throw a ``BluetoothError/notPresent`` error.
    public func write(_ value: Value) async throws {
        guard let injection,
              let characteristic = injection.characteristic else {
            throw BluetoothError.notPresent(service: injection?.serviceId, characteristic: configuration.id)
        }

        let requestData = value.encode()
        // TODO: update the written value in the injection! (after that)
        try await injection.peripheral.write(data: requestData, for: characteristic)
    }

    /// Write the value of a characteristic without expecting a confirmation.
    ///
    /// Writes the value of a characteristic without expecting a confirmation from the peripheral.
    ///
    /// - Note: The write operation is specified in Bluetooth Core Specification, Volume 3,
    ///     Part G, 4.9.1 Write Without Response.
    /// - Parameter value: The value you want to write.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    ///     It might also throw a ``BluetoothError/notPresent`` error.
    public func writeWithoutResponse(_ value: Value) async throws {
        guard let injection,
                let characteristic = injection.characteristic else {
            throw BluetoothError.notPresent(service: injection?.serviceId, characteristic: configuration.id)
        }

        let data = value.encode()
        // TODO: update the written value in the injection! (after that)
        await injection.peripheral.writeWithoutResponse(data: data, for: characteristic)
    }
}
