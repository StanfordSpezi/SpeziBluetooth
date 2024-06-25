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
@Observable
@propertyWrapper
public final class DeviceState<Value>: @unchecked Sendable {
    private let keyPath: KeyPath<BluetoothPeripheral, Value>
    private(set) var injection: DeviceStatePeripheralInjection<Value>?
    private var _injectedValue = ObservableBox<Value?>(nil)

    var objectId: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    /// Access the device state.
    public var wrappedValue: Value {
        guard let injection else {
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
        DeviceStateAccessor(id: objectId, injection: injection, injectedValue: _injectedValue)
    }


    /// Provide a `KeyPath` to the device state you want to access.
    /// - Parameter keyPath: The `KeyPath` to a property of the underlying ``BluetoothPeripheral`` instance.
    public init(_ keyPath: KeyPath<BluetoothPeripheral, Value>) {
        self.keyPath = keyPath
    }


    func inject(bluetooth: Bluetooth, peripheral: BluetoothPeripheral) {
        let injection = DeviceStatePeripheralInjection(bluetooth: bluetooth, peripheral: peripheral, keyPath: keyPath)
        self.injection = injection

        injection.assumeIsolated { injection in
            injection.setup()
        }
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
        if let injected = _injectedValue.value {
            return injected
        }

        let value: Any? = switch keyPath {
        case \.id:
            nil // we cannot provide a stable id?
        case \.name:
            Optional<String>.none as Any
        case \.state:
            PeripheralState.disconnected
        case \.advertisementData:
            AdvertisementData([:])
        case \.rssi:
            Int(UInt8.max)
        case \.services:
            Optional<[GATTService]>.none as Any
        default:
            nil
        }

        guard let value else {
            return nil
        }

        guard let value = value as? Value else {
            preconditionFailure("Default value \(value) was not the expected type for \(keyPath)")
        }
        return value
    }
}
