//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


/// Declare a characteristic within a Bluetooth service.
///
/// This property wrapper can be used to declare a Bluetooth characteristic within a ``BluetoothService``.
/// // TODO docs?
///
/// ## Topics
///
/// ### Retrieving Characteristic Accessor
/// - ``projectedValue``
/// - ``CharacteristicAccessors``
///
/// ### Reading a value
/// - ``CharacteristicAccessors/read()``
///
/// ### Controlling notifications
/// - ``CharacteristicAccessors/isNotifying``
/// - ``CharacteristicAccessors/enableNotifications(_:)``
///
/// ### Writing a value
/// - ``CharacteristicAccessors/write(_:)``
/// - ``CharacteristicAccessors/write(_:expecting:)``
/// - ``CharacteristicAccessors/writeWithoutResponse(_:)``
///
/// ### Characteristic properties
/// - ``CharacteristicAccessors/properties``
/// - ``CharacteristicAccessors/descriptors``
@Observable
@propertyWrapper
public class Characteristic<Value> {
    private let id: CBUUID
    private let discoverDescriptors: Bool

    private let defaultValue: Value?
    private let defaultNotify: Bool

    var description: CharacteristicDescription {
        CharacteristicDescription(id: id, discoverDescriptors: discoverDescriptors)
    }

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

    fileprivate init(wrappedValue: Value? = nil, characteristic: CBUUID, notify: Bool, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.defaultValue = wrappedValue
        self.id = characteristic
        self.defaultNotify = notify
        self.discoverDescriptors = discoverDescriptors
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
    public convenience init(wrappedValue: Value? = nil, id: String, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), discoverDescriptors: discoverDescriptors)
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: false, discoverDescriptors: discoverDescriptors)
    }
}


extension Characteristic where Value: ByteDecodable {
    public convenience init(wrappedValue: Value? = nil, id: String, notify: Bool = false, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), notify: notify, discoverDescriptors: discoverDescriptors)
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID, notify: Bool = false, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: notify, discoverDescriptors: discoverDescriptors)
    }
}


extension Characteristic where Value: ByteCodable { // reduce ambiguity
    public convenience init(wrappedValue: Value? = nil, id: String, notify: Bool = false, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), notify: notify, discoverDescriptors: discoverDescriptors)
    }

    public convenience init(wrappedValue: Value? = nil, id: CBUUID, notify: Bool = false, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: notify, discoverDescriptors: discoverDescriptors)
    }
}


extension Characteristic: ServiceVisitable {
    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
