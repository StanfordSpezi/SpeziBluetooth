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
    let serviceId: CBUUID
    var characteristic: CBCharacteristic? // nil if device is not connected yet
    var notify: Bool

    init(peripheral: BluetoothPeripheral, serviceId: CBUUID, characteristic: CBCharacteristic?, notify: Bool) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.characteristic = characteristic
        self.notify = notify
    }
}

private protocol DecodableCharacteristic {
    associatedtype Value: ByteDecodable

    @MainActor
    func setup()

    @MainActor
    func handleUpdateValue(_ data: Data?)
}


@Observable
@propertyWrapper
public class Characteristic<Value> {
    let id: CBUUID
    private let defaultNotify: Bool // TODO: this should be updated once we enable notifications via the accessors type?

    public private(set) var wrappedValue: Value?
    // TODO: update the wrapped value!

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

    private var context: CharacteristicContext?

    // TODO auto subscribe to notify
    fileprivate init(wrappedValue: Value? = nil, characteristic: CBUUID, notify: Bool) {
        self.wrappedValue = wrappedValue
        self.id = characteristic
        self.defaultNotify = notify
    }


    @MainActor
    func inject(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: CBService?) {
        let characteristic = service?.characteristics?.first(where: { $0.uuid == self.id })

        // TODO: subscribe to updates on the services property, to set the characteristics property eventually?
        self.context = CharacteristicContext(peripheral: peripheral, serviceId: serviceId, characteristic: characteristic, notify: defaultNotify)

        trackServicesUpdates()

        if let instance = self as? any DecodableCharacteristic {
            instance.setup()
        }
    }


    private func trackServicesUpdates() {
        guard let context else {
            return
        }

        withObservationTracking {
            _ = context.peripheral.services
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in // TODO: main actor?
                self?.handleServicesChange()
            }
            self?.trackServicesUpdates()
        }
    }

    @MainActor
    private func handleServicesChange() {
        guard let context else {
            return // TODO: debug this?
        }

        let service = context.peripheral.services?.first(where: { $0.uuid == context.serviceId })
        let characteristic = service?.characteristics?.first(where: { $0.uuid == self.id })

        context.characteristic = characteristic

        if context.characteristic != nil {
            updateNotificationSubscription()
            // TODO: check if we already have a notification handler registered??
        } else {
            wrappedValue = nil
        }

        if context.characteristic == nil {
            wrappedValue = nil
        }
    }

    private func updateNotificationSubscription() {
        guard let context else {
            return
        }

        if context.notify {
            if let characteristic = context.characteristic { // TODO: make sure stuff!
                Task { // TODO: synchronization??
                    // TODO: track registration!
                    await context.peripheral.registerNotifications(for: characteristic) { [weak self] data in
                        self?.handleCharacteristicValueChange(data)
                    }
                }
            }
        } else {
            // TODO: Remove notification subscription!
        }
    }

    private func handleCharacteristicValueChange(_ data: Data?) {
        guard let decodable = self as? any DecodableCharacteristic else {
            return
        }

        Task { @MainActor in
            // TODO: unwrap context and characteristic beforehand?
            decodable.handleUpdateValue(data)
        }
    }
}


extension Characteristic: DecodableCharacteristic where Value: ByteDecodable {
    @MainActor
    func setup() {
        guard let context else {
            return // this is given!
        }

        if let characteristic = context.characteristic {
            // handle assigning the initial value!
            if let value = characteristic.value {
                handleUpdateValue(value)
            }

            updateNotificationSubscription()
        }
    }

    @MainActor
    func handleUpdateValue(_ data: Data?) {
        guard let data else {
            wrappedValue = nil
            return
        }

        guard let value = Value(data: data) else {
            // TODO: make it a warning!!!
            return
        }
        self.wrappedValue = value
    }
}


extension Characteristic where Value: ByteEncodable {
    // TODO: make initializers a protocol? => allow for (short:base:) initializer!
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
