//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import Observation


/// Retrieve state of a Bluetooth peripheral.
///
/// This property wrapper can be used within your ``BluetoothDevice`` or ``BluetoothService`` models to
/// get access to the state of your Bluetooth peripheral.
///
/// - Note: Every `DeviceState` is [Observable](https://developer.apple.com/documentation/Observation) out of the box.
///     You can easily use the state value within your SwiftUI view and the view will be automatically re-rendered
///     when the state value is updated.
///
/// Below is a short code example that demonstrate the usage of the `DeviceState` property wrapper to retrieve the name and current ``BluetoothState``
/// of a device.
///
/// - Important: The  `wrappedValue` of the property wrapper can only be safely accessed after the initializer returned. Accessing within the initializer will result in a runtime crash.
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
/// - ``DeviceStateAccessor/onChange(initial:perform:)-8x9cj``
/// - ``DeviceStateAccessor/onChange(initial:perform:)-9igc9``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``DeviceStateAccessor``
@propertyWrapper
public struct DeviceState<Value: Sendable>: Sendable {
    final class Storage: Sendable {
        let keyPath: KeyPath<BluetoothPeripheral, Value>
        let injection = ManagedAtomicLazyReference<DeviceStatePeripheralInjection<Value>>()
        /// To support testing support.
        let testInjections = ManagedAtomicLazyReference<DeviceStateTestInjections<Value>>()

        init(keyPath: KeyPath<BluetoothPeripheral, Value>) {
            self.keyPath = keyPath
        }
    }

    private let storage: Storage

    /// Access the device state.
    public var wrappedValue: Value {
        guard let injection = storage.injection.load() else {
            if let defaultValue { // better support previews with some default values
                return defaultValue
            }

            preconditionFailure(
                """
                Failed to access bluetooth device state. Make sure your @DeviceState is only declared within your bluetooth device class \
                that is managed by SpeziBluetooth.
                """
            )
        }
        return injection.value
    }


    /// Retrieve a temporary accessors instance.
    public var projectedValue: DeviceStateAccessor<Value> {
        DeviceStateAccessor(storage)
    }


    /// Provide a `KeyPath` to the device state you want to access.
    /// - Parameter keyPath: The `KeyPath` to a property of the underlying ``BluetoothPeripheral`` instance.
    public init(_ keyPath: KeyPath<BluetoothPeripheral, Value>) {
        self.storage = Storage(keyPath: keyPath)
    }


    @SpeziBluetooth
    func inject(bluetooth: Bluetooth, peripheral: BluetoothPeripheral) {
        let injection = storage.injection
            .storeIfNilThenLoad(DeviceStatePeripheralInjection(bluetooth: bluetooth, peripheral: peripheral, keyPath: storage.keyPath))
        assert(injection.peripheral === peripheral, "\(#function) cannot be called more than once in the lifetime of a \(Self.self) instance")

        injection.setup()
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


extension DeviceState {
    var defaultValue: Value? {
        if let injected = storage.testInjections.load()?.injectedValue {
            return injected
        }

        return DeviceStateTestInjections<Value>.artificialValue(for: storage.keyPath)
    }
}
