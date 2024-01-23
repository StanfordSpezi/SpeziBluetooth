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
public struct CharacteristicAccessors<Value> {
    private let information: Characteristic<Value>.Information
    private let context: CharacteristicPeripheralAssociation<Value>?


    init(information: Characteristic<Value>.Information, context: CharacteristicPeripheralAssociation<Value>?) {
        self.information = information
        self.context = context
    }
}


extension CharacteristicAccessors {
    /// Determine if the characteristic is available.
    ///
    /// Returns true if the characteristic is available for the current device.
    /// It is true if (a) the device is connected and (b) the device exposes the requested characteristic.
    public var isPresent: Bool {
        context?.characteristic != nil
    }

    /// Properties of the characteristic.
    ///
    /// Nil if device is not connected.
    public var properties: CBCharacteristicProperties? {
        context?.characteristic?.properties
    }

    /// Descriptors of the characteristic.
    ///
    /// Nil if device is not connected or descriptors are not yet discovered.
    public var descriptors: [CBDescriptor]? { // swiftlint:disable:this discouraged_optional_collection
        context?.characteristic?.descriptors
    }
}


extension CharacteristicAccessors where Value: ByteDecodable {
    /// Characteristic is currently notifying about updated values.
    ///
    /// This is also false if device is not connected.
    public var isNotifying: Bool {
        context?.characteristic?.isNotifying ?? false
    }


    public func onChange(_ perform: @escaping (Value) -> Void) { // TODO: docs
        guard let context else {
            // We save the instance in the global registrar if its available.
            // It will be available if w  e are instantiated through the Bluetooth module.
            // This indirection is required to support self referencing closures without encountering a strong reference cycle.
            NotificationRegistrar.instance?.insert(for: information, closure: perform)
            return
        }

        context.setNotificationClosure(perform)
    }


    /// Enable or disable characteristic notifications.
    /// - Parameter enable: Flag indicating if notifications should be enabled.
    public func enableNotifications(_ enable: Bool = true) async {
        guard let context else {
            // this will value will be populated to the context once it is set up // TODO: rename all context!
            information.defaultNotify = enable
            return
        }

        if enable {
            await context.enableNotifications()
        } else {
            await context.disableNotifications()
        }
    }

    /// Read the current characteristic value from the remote peripheral.
    /// - Returns: The value that was read.
    /// - Throws: Throws an `CBError` or `CBATTError` if the read fails.
    ///     It might also throw a ``BluetoothError/notPresent`` or ``BluetoothError/incompatibleDataFormat`` error.
    @discardableResult
    public func read() async throws -> Value {
        guard let context,
            let characteristic = context.characteristic else {
            throw BluetoothError.notPresent
        }

        let data = try await context.peripheral.read(characteristic: characteristic)
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
        guard let context,
              let characteristic = context.characteristic else {
            throw BluetoothError.notPresent
        }

        let requestData = value.encode()
        try await context.peripheral.write(data: requestData, for: characteristic)
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
        guard let context,
                let characteristic = context.characteristic else {
            throw BluetoothError.notPresent
        }

        let data = value.encode()
        await context.peripheral.writeWithoutResponse(data: data, for: characteristic)
    }
}
