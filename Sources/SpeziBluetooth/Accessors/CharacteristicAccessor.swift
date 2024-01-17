//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


public struct CharacteristicAccessors<Value> {
    let id: CBUUID
    fileprivate let context: CharacteristicContext

    // TODO: dynamic member lookup for the characteristic? => unsafe access or something?

    init(id: CBUUID, context: CharacteristicContext) {
        self.id = id
        self.context = context
    }
}


extension CharacteristicAccessors where Value: ByteDecodable {
    // TODO: control notification + access current state
    // TODO: just bridged some peripheral accesses?

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
    public func write<Response: ByteDecodable>(_ value: Value, expecting response: Response.Type = Response.self) async throws -> Response {
        guard let characteristic = context.characteristic else {
            throw BluetoothError.notConnected
        }

        let requestData = value.encode()
        let responseData = try await context.peripheral.write(data: requestData, for: characteristic)

        guard let response = Response(data: responseData) else {
            throw BluetoothError.incompatibleDataFormat
        }

        return response
    }

    public func writeWithoutResponse(_ value: Value) async throws {
        guard let characteristic = context.characteristic else {
            throw BluetoothError.notConnected
        }

        // TODO: how to do non response write?
        let data = value.encode()
        await context.peripheral.writeWithoutResponse(data: data, for: characteristic)
    }
}


extension CharacteristicAccessors where Value: ByteCodable {
    public func write(_ value: Value) async throws -> Value {
        try await write(value, expecting: Value.self)
    }
}
