//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// Declare a service within a Bluetooth device.
///
/// This property wrapper can be used to declare a Bluetooth service within a ``BluetoothDevice``.
/// You must provide an instance to your ``BluetoothService`` implementation.
/// Refer to the respective documentation for more details.
///
/// Below is a short code example on how you would declare your [Bluetooth Heart Rate Service](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0)
/// implementation within your Bluetooth device.
/// 
/// ```swift
/// class MyDevice: BluetoothDevice {
///     @Service var heartRate = HeartRateService()
/// }
/// ```
///
/// ## Topics
///
/// ### Declaring a Service
/// - ``init(wrappedValue:)``
///
/// ### Inspecting a Service
/// - ``ServiceAccessor/isPresent``
/// - ``ServiceAccessor/isPrimary``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``ServiceAccessor``
@propertyWrapper
public final class Service<S: BluetoothService>: @unchecked Sendable {
    var id: CBUUID {
        S.id
    }
    private var injection: ServicePeripheralInjection?

    /// Access the service instance.
    public let wrappedValue: S

    /// Retrieve a temporary accessors instance.
    ///
    /// This type allows you to interact with a Service's properties.
    ///
    /// - Note: The accessor captures the service instance upon creation. Within the same `ServiceAccessor` instance
    ///     the view on the service is consistent. However, if you project a new `ServiceAccessor` instance right
    ///     after your access, the view on the service might have changed due to the asynchronous nature of SpeziBluetooth.
    public var projectedValue: ServiceAccessor {
        ServiceAccessor(id: id, injection: injection)
    }

    /// Declare a service.
    /// - Parameters:
    ///   - wrappedValue: The service instance.
    public init(wrappedValue: S) {
        self.wrappedValue = wrappedValue
    }


    func inject(peripheral: BluetoothPeripheral, service: GATTService?) {
        let injection = ServicePeripheralInjection(peripheral: peripheral, serviceId: id, service: service)
        self.injection = injection
        injection.assumeIsolated { injection in
            injection.setup()
        }
    }
}


extension Service: DeviceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
