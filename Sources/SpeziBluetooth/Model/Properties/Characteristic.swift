//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation

// TODO: change docs about init access!


/// Declare a characteristic within a Bluetooth service.
///
/// This property wrapper can be used to declare a Bluetooth characteristic within a ``BluetoothService``.
/// The value type of your property needs to be optional and conform to ``ByteEncodable``, ``ByteDecodable`` or ``ByteCodable`` respectively.
///
/// If your device is connected, the characteristic value is automatically updated upon a characteristic read or a notify.
///
/// - Note: Every `Characteristic` is [Observable](https://developer.apple.com/documentation/Observation) out of the box.
///     So you can easily use the characteristic value within your SwiftUI view and it will be automatically re-rendered
///     when the characteristic value is updated.
///
/// The below code example demonstrates declaring the Firmware Revision characteristic of the Device Information service.
///
/// ```swift
/// class DeviceInformationService: BluetoothService {
///     @Characteristic(id: "2A26")
///     var firmwareRevision: String?
/// }
/// ```
///
/// ### Automatic Notifications
///
/// If your characteristic supports notifications, you can automatically subscribe to characteristic notifications
/// by supplying the `notify` initializer argument.
///
/// - Tip: If you want to react to every change of the characteristic value, you can use
///     ``CharacteristicAccessors/onChange(perform:)`` to set up your action.
///
/// The below code example uses the [Bluetooth Heart Rate Service](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0)
/// to demonstrate the automatic notifications feature for the Heart Rate Measurement characteristic.
///
/// ```swift
/// class HeartRateService: BluetoothService {
///     @Characteristic(id: "2A37", notify: true)
///     var heartRateMeasurement: HeartRateMeasurement?
///
///     init() {
///         $heartRateMeasurement.onChange(perform: processMeasurement)
///     }
///
///     func processMeasurement(_ measurement: HeartRateMeasurement) {
///         // make sure not to block the bluetooth task with heavy operations.
///         Task {
///             // process measurements ...
///         }
///     }
/// }
/// ```
///
/// ### Characteristic Interactions
///
/// To interact with a characteristic to read or write a value or enable or disable notifications,
/// you can use the ``projectedValue`` (`$` notation) to retrieve a temporary ``CharacteristicAccessors`` instance.
///
/// Do demonstrate this functionality, we completed the implementation of our Heart Rate Service
/// according to its [Specification](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0).
/// The example demonstrates reading and writing of characteristic values, controlling characteristic notifications,
/// and inspecting other properties like `isPresent`.
///
/// ```swift
/// class HeartRateService: BluetoothService {
///     @Characteristic(id: "2A37", notify: true)
///     var heartRateMeasurement: HeartRateMeasurement?
///     @Characteristic(id: "2A38")
///     var bodySensorLocation: UInt8?
///     @Characteristic(id: "2A39")
///     var heartRateControlPoint: UInt8?
///
///     var measurementsRunning: Bool {
///         $heartRateMeasurement.isNotifying
///     }
///
///     var energyExpendedFeatureSupported: Bool {
///         // characteristic is required to be present if feature is supported (see Heart Rate Service spec).
///         $heartRateControlPoint.isPresent
///     }
///
///
///     init() {}
///
///
///     func handleConnected() async throws { // manually called from the outside
///         try await $bodySensorLocation.read()
///         if energyExpendedFeatureSupported {
///             try await $heartRateControlPoint.write(0x01) // resets the energy expended measurement
///         }
///     }
///
///     func pauseMeasurements() async {
///         await $heartRateMeasurement.enableNotifications(false)
///     }
///
///     func resumeMeasurements() async {
///         await $heartRateMeasurement.enableNotifications()
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Declaring a Characteristic
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-8r34a``
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-bev4``
/// - ``init(wrappedValue:id:discoverDescriptors:)-6xq7e``
/// - ``init(wrappedValue:id:discoverDescriptors:)-2esyb``
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-4tg93``
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-9zex3``
///
/// ### Inspecting a Characteristic
/// - ``CharacteristicAccessors/isPresent``
/// - ``CharacteristicAccessors/properties``
/// - ``CharacteristicAccessors/descriptors``
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
/// - ``CharacteristicAccessors/writeWithoutResponse(_:)``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``CharacteristicAccessors``
@propertyWrapper
public class Characteristic<Value> {
    class Configuration {
        let id: CBUUID
        let discoverDescriptors: Bool

        var defaultNotify: Bool

        init(id: CBUUID, discoverDescriptors: Bool, defaultNotify: Bool) {
            self.id = id
            self.discoverDescriptors = discoverDescriptors
            self.defaultNotify = defaultNotify
        }
    }

    @Observable
    class ValueBox {
        var value: Value?

        init(_ value: Value?) {
            self.value = value
        }
    }

    private let configuration: Configuration
    private let valueBox: ValueBox
    private var association: CharacteristicPeripheralAssociation<Value>?

    var description: CharacteristicDescription {
        CharacteristicDescription(id: configuration.id, discoverDescriptors: configuration.discoverDescriptors)
    }

    /// Access the current characteristic value.
    ///
    /// This is either the last read value or the latest notified value.
    public var wrappedValue: Value? {
        valueBox.value
    }

    /// Retrieve a temporary accessors instance.
    public var projectedValue: CharacteristicAccessors<Value> {
        CharacteristicAccessors(configuration: configuration, association: association)
    }

    fileprivate init(wrappedValue: Value? = nil, characteristic: CBUUID, notify: Bool, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.configuration = .init(id: characteristic, discoverDescriptors: discoverDescriptors, defaultNotify: notify)
        self.valueBox = ValueBox(wrappedValue)
    }


    @MainActor
    func inject(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: GATTService?) {
        let characteristic = service?.getCharacteristic(id: configuration.id)

        // Any potential onChange closure registration that happened within the initializer. Forward them to the association
        let notificationClosure = NotificationRegistrar.instance?.retrieve(for: configuration)

        let association = CharacteristicPeripheralAssociation<Value>(
            peripheral: peripheral,
            serviceId: serviceId,
            characteristicId: configuration.id,
            valueBox: valueBox,
            characteristic: characteristic,
            notificationClosure: notificationClosure
        )

        self.association = association

        Task {
            await association.setup(defaultNotify: configuration.defaultNotify)
        }
    }

    func clearState() {
        association?.clearState()
    }
}


extension Characteristic where Value: ByteEncodable {
    /// Declare a write-only characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - discoverDescriptors: Flag if characteristic descriptors should be discovered automatically.
    public convenience init(wrappedValue: Value? = nil, id: String, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), discoverDescriptors: discoverDescriptors)
    }

    /// Declare a write-only characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - discoverDescriptors: Flag if characteristic descriptors should be discovered automatically.
    public convenience init(wrappedValue: Value? = nil, id: CBUUID, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: false, discoverDescriptors: discoverDescriptors)
    }
}


extension Characteristic where Value: ByteDecodable {
    /// Declare a read-only characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - notify: Automatically subscribe to characteristic notifications if supported.
    ///   - discoverDescriptors: Flag if characteristic descriptors should be discovered automatically.
    public convenience init(wrappedValue: Value? = nil, id: String, notify: Bool = false, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), notify: notify, discoverDescriptors: discoverDescriptors)
    }

    /// Declare a read-only characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - notify: Automatically subscribe to characteristic notifications if supported.
    ///   - discoverDescriptors: Flag if characteristic descriptors should be discovered automatically.
    public convenience init(wrappedValue: Value? = nil, id: CBUUID, notify: Bool = false, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: notify, discoverDescriptors: discoverDescriptors)
    }
}


extension Characteristic where Value: ByteCodable { // reduce ambiguity
    /// Declare a read and write characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - notify: Automatically subscribe to characteristic notifications if supported.
    ///   - discoverDescriptors: Flag if characteristic descriptors should be discovered automatically.
    public convenience init(wrappedValue: Value? = nil, id: String, notify: Bool = false, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id), notify: notify, discoverDescriptors: discoverDescriptors)
    }

    /// Declare a read and write characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - notify: Automatically subscribe to characteristic notifications if supported.
    ///   - discoverDescriptors: Flag if characteristic descriptors should be discovered automatically.
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
