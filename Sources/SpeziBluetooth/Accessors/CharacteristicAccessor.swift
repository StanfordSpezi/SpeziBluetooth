//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


public struct CharacteristicAccessors<Value> {
    public let id: CBUUID // TODO: do we need access to this?
    fileprivate let context: CharacteristicContext // TODO: just capture UUIDs and not characteristic and service instances?

    // TODO dynamic member lookup for the characteristic? => unsafe access or something?

    init(id: CBUUID, context: CharacteristicContext) {
        self.id = id
        self.context = context
    }
}


extension CharacteristicAccessors where Value: ByteDecodable {
    // TODO: control notification + access current state
    // TODO: just bridged some peripheral accesses?

    public func read() async throws -> Value {
        let data = try await context.peripheral.read(characteristic: context.characteristic)
        guard let value = Value(data: data) else {
            // TODO: how to handle this incompatibility?
            throw BluetoothError.concurrentCharacteristicAccess
        }
        return value
    }
}


extension CharacteristicAccessors where Value: ByteEncodable {
    public func write<Response: ByteDecodable>(_ value: Value, expecting response: Response.Type = Response.self) async throws -> Response {
        let requestData = value.encode()
        let responseData = try await context.peripheral.write(data: requestData, for: context.characteristic)

        guard let response = Response(data: responseData) else {
            // TODO: how to handle this incompatibility?
            throw BluetoothError.concurrentCharacteristicAccess
        }

        return response
    }

    public func writeWithoutResponse(_ value: Value) async throws {
        // TODO: how to do non response write?
        let data = value.encode()
        try await context.peripheral.writeWithoutResponse(data: data, for: context.characteristic)
    }
}


extension CharacteristicAccessors where Value: ByteCodable {
    public func write(_ value: Value) async throws -> Value {
        try await write(value, expecting: Value.self)
    }
}
