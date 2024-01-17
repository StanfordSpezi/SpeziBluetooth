//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


class CharacteristicContext {
    let peripheral: BluetoothPeripheral
    let characteristic: CBCharacteristic

    init(peripheral: BluetoothPeripheral, characteristic: CBCharacteristic) {
        self.peripheral = peripheral
        self.characteristic = characteristic
    }
}


@Observable
@propertyWrapper
public class Characteristic<Value> {
    let id: CBUUID // TODO: we need to inject the serviceId this characteristic lives in!

    // TODO: how to we get the characteristic id?
    public private(set) var wrappedValue: Value? // TODO: make sure observable works!
    // TODO: update the wrapped value!

    public var projectedValue: CharacteristicAccessors<Value> {
        guard let context else {
            // TODO: we might want to fail gracefully? with a non-connected error!
            preconditionFailure("Failed to ") // TODO: message!
        }
        return CharacteristicAccessors(id: id, context: context)
    }

    // TODO: this must not capture the bluetooth device!!!
    // TODO: how to we deal with non connected devices or referencing disappearing?
    var context: CharacteristicContext? // TODO: injected at some point!

    // TODO auto subscribe to notify
    fileprivate init(wrappedValue: Value? = nil, characteristic: CBUUID) {
        self.wrappedValue = wrappedValue
        self.id = characteristic
        // TODO: allow to specify auto subscription!
    }
}


extension Characteristic where Value: ByteEncodable {
    // TODO: make initializers a protocol? => allow for (short:base:) initializer!
    public convenience init(wrappedValue: Value? = nil, id: String) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id))
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID) {
        self.init(wrappedValue: wrappedValue, characteristic: id)
    }
}


extension Characteristic where Value: ByteDecodable {
    public convenience init(wrappedValue: Value? = nil, id: String) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id))
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID) {
        self.init(wrappedValue: wrappedValue, characteristic: id)
    }
}


extension Characteristic where Value: ByteCodable { // reduce ambiguity
    public convenience init(wrappedValue: Value? = nil, id: String) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id))
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID) {
        self.init(wrappedValue: wrappedValue, characteristic: id)
    }
}


extension Characteristic: ServiceVisitable {
    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
