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
///     @Service(id: "180D")
///     var heartRate = HeartRateService()
/// }
/// ```
///
/// ## Topics
///
/// ### Declaring a Service
/// - ``init(wrappedValue:id:)-2mo8b``
/// - ``init(wrappedValue:id:)-1if8d``
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
public class Service<S: BluetoothService> {
    let id: CBUUID
    private var injection: ServicePeripheralInjection?

    /// Access the service instance.
    public let wrappedValue: S

    /// Retrieve a temporary accessors instance.
    public var projectedValue: ServiceAccessor {
        ServiceAccessor(id: id, injection: injection)
    }

    /// Declare a service.
    /// - Parameters:
    ///   - wrappedValue: The service instance.
    ///   - id: The service id.
    public convenience init(wrappedValue: S, id: String) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id))
    }

    /// Declare a service.
    /// - Parameters:
    ///   - wrappedValue: The service instance.
    ///   - id: The service id.
    public init(wrappedValue: S, id: CBUUID) {
        self.wrappedValue = wrappedValue
        self.id = id
    }

    @MainActor
    func inject(peripheral: BluetoothPeripheral, service: GATTService?) {
        let injection = ServicePeripheralInjection(peripheral: peripheral, serviceId: id, service: service)
        self.injection = injection

        injection.setup()
    }
}


extension Service: DeviceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
