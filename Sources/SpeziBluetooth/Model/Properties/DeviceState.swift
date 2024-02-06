//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation


/// Retrieve state of a Bluetooth peripheral.
///
/// This property wrapper can be used within your ``BluetoothDevice`` or ``BluetoothService`` models to
/// get access to the state of your Bluetooth peripheral.
///
/// Below is a short code example that demonstrate the usage of the `DeviceState` property wrapper to retrieve the name and current ``BluetoothState``
/// of a device.
///
/// - Important: The `@DeviceState` property wrapper can only be accessed after the initializer returned. Accessing within the initializer will result in a runtime crash.
///
/// ```swift
/// class ExampleDevice: BluetoothDevice {
///     @DeviceState(\.name)
///     var name: String?
///
///     @DeviceState(\.state)
///     var state: BluetoothState
///
///     init() {
///         // ...
///     }
/// }
/// ```
///
/// ### Handling changes
///
/// While the `DeviceState` property wrapper is fully compatible with Apples Observation framework, it might be
/// useful to explicitly handle updates to the a device state.
/// You can register a change handler via the accessor type obtained through the projected value.
///
/// The below code examples demonstrates this approach:
///
/// ```swift
/// class MyDevice: BluetoothDevice {
///     @DeviceState(\.state)
///     var state: PeripheralState
///
///     init() {
///         $state.onChange(perform: handleStateChange)
///     }
///
///     handleStateChange(_ state: PeripheralState) {
///         // ...
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Declaring device state
/// - ``init(_:)``
///
/// ### Available Device States
/// - ``BluetoothPeripheral/id``
/// - ``BluetoothPeripheral/name``
/// - ``BluetoothPeripheral/state``
/// - ``BluetoothPeripheral/rssi``
/// - ``BluetoothPeripheral/advertisementData``
///
/// ### Get notified about changes
/// - ``DeviceStateAccessor/onChange(perform:)``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``DeviceStateAccessor``
@Observable
@propertyWrapper
public class DeviceState<Value> {
    private let keyPath: KeyPath<BluetoothPeripheral, Value>
    private(set) var injection: DeviceStatePeripheralInjection<Value>?

    var objectId: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    /// Access the device state.
    public var wrappedValue: Value {
        guard let injection else {
            preconditionFailure(
                """
                Failed to access bluetooth device state. Make sure your @DeviceState is only declared within your bluetooth device class \
                that is managed by SpeziBluetooth.
                """
            )
        }
        return injection.peripheral[keyPath: keyPath]
    }


    /// Retrieve a temporary accessors instance.
    public var projectedValue: DeviceStateAccessor<Value> {
        DeviceStateAccessor(id: objectId, injection: injection)
    }


    /// Provide a `KeyPath` to the device state you want to access.
    /// - Parameter keyPath: The `KeyPath` to a property of the underlying ``BluetoothPeripheral`` instance.
    public init(_ keyPath: KeyPath<BluetoothPeripheral, Value>) {
        self.keyPath = keyPath
    }


    func inject(peripheral: BluetoothPeripheral) -> DeviceStatePeripheralInjection<Value> {
        let changeClosure = ClosureRegistrar.instance?.retrieve(for: objectId, value: Value.self)

        let injection = DeviceStatePeripheralInjection(peripheral: peripheral, keyPath: keyPath, onChangeClosure: changeClosure)
        self.injection = injection

        return injection
    }
}


extension DeviceState: DeviceVisitable, ServiceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }

    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
