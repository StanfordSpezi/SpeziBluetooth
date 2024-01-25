//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Retrieve state of a Bluetooth peripheral.
///
/// This property wrapper can be used within your ``BluetoothDevice`` or ``BluetoothService`` models to
/// get access to the state of your Bluetooth peripheral.
///
/// Below is a short code example that demonstrate the usage of the `DeviceState` property wrapper to retrieve the name and current ``BluetoothState``
/// of a device.
///
/// - Note: The `@DeviceState` property wrapper can only be accessed after the initializer returned. Accessing within the initializer will result in a runtime crash.
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
/// ## Topics
///
/// ### Available Device States
/// - ``BluetoothPeripheral/id``
/// - ``BluetoothPeripheral/name``
/// - ``BluetoothPeripheral/state``
/// - ``BluetoothPeripheral/rssi``
/// - ``BluetoothPeripheral/advertisementData``
///
/// ### Declaring device state
/// - ``init(_:)``
///
/// ### Property wrapper access
/// - ``wrappedValue``
@propertyWrapper
public class DeviceState<Value> {
    private let keyPath: KeyPath<BluetoothPeripheral, Value>
    private var peripheral: BluetoothPeripheral?

    /// Access the device state.
    public var wrappedValue: Value {
        guard let peripheral else {
            preconditionFailure(
                """
                Failed to access bluetooth device state. Make sure your @DeviceState is only declared within your bluetooth device class \
                that is managed by SpeziBluetooth.
                """
            )
        }
        return peripheral[keyPath: keyPath]
    }


    // TODO: support onChange handlers?


    /// Provide a `KeyPath` to the device state you want to access.
    /// - Parameter keyPath: The `KeyPath` to a property of the underlying ``BluetoothPeripheral`` instance.
    public init(_ keyPath: KeyPath<BluetoothPeripheral, Value>) {
        self.keyPath = keyPath
    }


    func inject(peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
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
