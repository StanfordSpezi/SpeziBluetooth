//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


@Observable
@propertyWrapper
public class Characteristic<Value> { // TODO: topics to CharacteristicAccessors
    let id: CBUUID

    private let defaultValue: Value?
    private let defaultNotify: Bool

    public var wrappedValue: Value? {
        guard let context else {
            return defaultValue
        }
        return context.value
    }

    public var projectedValue: CharacteristicAccessors<Value> {
        guard let context else {
            preconditionFailure(
                """
                Failed to access bluetooth characteristic. Make sure your @Characteristic is only declared within your bluetooth device class \
                that is managed by SpeziBluetooth.
                """
            )
        }
        return CharacteristicAccessors(id: id, context: context)
    }

    private var context: CharacteristicContext<Value>?

    fileprivate init(wrappedValue: Value? = nil, characteristic: CBUUID, notify: Bool) { // swiftlint:disable:this function_default_parameter_at_end
        self.defaultValue = wrappedValue
        self.id = characteristic
        self.defaultNotify = notify
    }


    @MainActor
    func inject(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: CBService?) {
        let characteristic = service?.characteristics?.first(where: { $0.uuid == self.id })

        let context = CharacteristicContext<Value>(
            peripheral: peripheral,
            serviceId: serviceId,
            characteristicId: self.id,
            characteristic: characteristic
        )

        self.context = context

        Task {
            await context.setup(defaultNotify: defaultNotify)
        }
    }
}


extension Characteristic where Value: ByteEncodable {
    public convenience init(wrappedValue: Value? = nil, id: String) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id))
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID) {
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: false)
    }
}


extension Characteristic where Value: ByteDecodable {
    public convenience init(wrappedValue: Value? = nil, id: String, notify: Bool = false) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), notify: notify)
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID, notify: Bool = false) {
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: notify)
    }
}


extension Characteristic where Value: ByteCodable { // reduce ambiguity
    public convenience init(wrappedValue: Value? = nil, id: String, notify: Bool = false) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), notify: notify)
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID, notify: Bool = false) {
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: notify)
    }
}


extension Characteristic: ServiceVisitable {
    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
