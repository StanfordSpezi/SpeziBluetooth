//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// TODO: docs
///
/// ## Topics
///
/// ### Characteristic properties
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
    let id: CBUUID
    fileprivate let context: CharacteristicContext<Value>


    init(id: CBUUID, context: CharacteristicContext<Value>) {
        self.id = id
        self.context = context
    }
}


extension CharacteristicAccessors where Value: ByteDecodable {
    /// Characteristic is currently notifying about updated values.
    ///
    /// This is false if device is not connected.
    public var isNotifying: Bool {
        context.characteristic?.isNotifying ?? false
    }

    /// Properties of the characteristic.
    ///
    /// Nil if device is not connected.
    public var properties: CBCharacteristicProperties? {
        context.characteristic?.properties
    }

    /// Descriptors of the characteristic.
    ///
    /// Nil if device is not connected or descriptors are not yet discovered.
    public var descriptors: [CBDescriptor]? { // swiftlint:disable:this discouraged_optional_collection
        context.characteristic?.descriptors
    }


    public func enableNotifications(_ enable: Bool = true) async {
        if enable {
            await context.enableNotifications()
        } else {
            await context.disableNotifications()
        }
    }

    public func read() async throws -> Value {
        guard let characteristic = context.characteristic else {
            throw BluetoothError.notConnected
        }

        let data = try await context.peripheral.read(characteristic: characteristic)
        guard let value = Value(data: data) else {
            throw BluetoothError.incompatibleDataFormat
        }
        return value
    }
}


extension CharacteristicAccessors where Value: ByteEncodable {
    public func write(_ value: Value) async throws {
        guard let characteristic = context.characteristic else {
            throw BluetoothError.notConnected
        }

        let requestData = value.encode()
        try await context.peripheral.write(data: requestData, for: characteristic)
    }

    public func writeWithoutResponse(_ value: Value) async throws {
        guard let characteristic = context.characteristic else {
            throw BluetoothError.notConnected
        }

        let data = value.encode()
        await context.peripheral.writeWithoutResponse(data: data, for: characteristic)
    }
}
