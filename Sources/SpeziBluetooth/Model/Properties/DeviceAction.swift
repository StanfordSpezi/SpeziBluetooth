//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics


/// Control an action of a Bluetooth peripheral.
///
/// This property wrapper can be used within your ``BluetoothDevice`` or ``BluetoothService`` models to
/// control an action of a Bluetooth peripheral.
///
/// Below is a short code example that demonstrates the usage of the `DeviceAction` property wrapper to
/// execute the connect and disconnect actions of a device.
///
/// - Important: The `@DeviceAction` property wrapper can only be accessed after the initializer returned. Accessing within the initializer will result in a runtime crash.
///
/// ```swift
/// class ExampleDevice: BluetoothDevice {
///     @DeviceAction(\.connect)
///     var connect
///
///     @DeviceAction(\.disconnect)
///     var disconnect
///
///     init() {
///         // ...
///     }
///
///     /// Called when all measurements were successfully transmitted.
///     func transmissionFinished() async {
///         // ...
///         await disconnect()
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Declaring a device action
/// - ``init(_:)``
///
/// ### Available Device Actions
/// - ``DeviceActions/connect``
/// - ``DeviceActions/disconnect``
/// - ``DeviceActions/readRSSI``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``DeviceActionAccessor``
///
/// ### Device Actions
/// - ``DeviceActions``
@propertyWrapper
public struct DeviceAction<Action: _BluetoothPeripheralAction>: Sendable {
    final class Storage: Sendable {
        let injection = ManagedAtomicLazyReference<DeviceActionPeripheralInjection>()
        let testInjections = ManagedAtomicLazyReference<DeviceActionTestInjections<Action.ClosureType>>()

        init() {}
    }

    private let storage = Storage()


    /// Access the device action.
    public var wrappedValue: Action {
        guard let injection = storage.injection.load() else {
            if let injectedClosure = storage.testInjections.load()?.injectedClosure {
                return Action(.injected(injectedClosure))
            }

            preconditionFailure(
                """
                Failed to access bluetooth device action. Make sure your @DeviceAction is only declared within your bluetooth device class \
                that is managed by SpeziBluetooth.
                """
            )
        }
        return Action(.peripheral(injection.peripheral))
    }

    /// Retrieve a temporary accessors instance.
    public var projectedValue: DeviceActionAccessor<Action> {
        DeviceActionAccessor(storage)
    }


    /// Provide a `KeyPath` to the device action you want to access.
    /// - Parameter keyPath: The `KeyPath` to a property of ``DeviceActions``.
    public init(_ keyPath: KeyPath<DeviceActions, Action.Type>) {}


    func inject(bluetooth: Bluetooth, peripheral: BluetoothPeripheral) {
        let injection = storage.injection.storeIfNilThenLoad(DeviceActionPeripheralInjection(bluetooth: bluetooth, peripheral: peripheral))
        assert(injection.peripheral === peripheral, "\(#function) cannot be called more than once in the lifetime of a \(Self.self) instance")
    }
}


extension DeviceAction: DeviceVisitable, ServiceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }

    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
