//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


public struct CharacteristicAccessors<Value> {
    public let id: CBUUID
    fileprivate let context: CharacteristicContext

    // TODO dynamic member lookup for the characteristic? => unsafe access or somehting?

    init(id: CBUUID, context: CharacteristicContext) {
        self.id = id
        self.context = context
    }
}


extension CharacteristicAccessors where Value: ByteDecodable {
    // TODO: control notification + access current state
    // TODO: just bridged some peripheral accesses?

    public func read() async throws -> Value {
        // TODO: actually retrieve the value from the bluetooth device?
        context.peripheral.readValue(for: context.characteristic)
    }
}


extension CharacteristicAccessors where Value: ByteEncodable {
    public func write<Response: ByteDecodable>(_ value: Value, expecting response: Response.Type = Response.self) async throws -> Response {
        let data = value.encode()
        context.peripheral.writeValue(data, for: context.characteristic, type: .withResponse)
        // TODO: does response value make sense?
        // TODO: actually return the response!
    }

    @_disfavoredOverload
    public func write(_ value: Value) async throws {
        // TODO: how to do non response write?
        let data = value.encode()
        context.peripheral.writeValue(data, for: context.characteristic, type: .withoutResponse)
    }
}


extension CharacteristicAccessors where Value: ByteCodable {
    public func write(_ value: Value) async throws -> Value {
        try await write(value, expecting: Value.self)
    }
}
