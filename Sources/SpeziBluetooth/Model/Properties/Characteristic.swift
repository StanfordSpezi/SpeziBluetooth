//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import CoreBluetooth
import Foundation


/// Declare a characteristic within a Bluetooth service.
///
/// This property wrapper can be used to declare a Bluetooth characteristic within a ``BluetoothService``.
/// The value type of your property needs to be optional and conform to
/// [`ByteEncodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/byteencodable),
/// [`ByteDecodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/1.0.0/documentation/bytecoding/bytedecodable) or
/// [`ByteCodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/bytecodable) respectively.
///
/// If your device is connected, the characteristic value is automatically updated upon a characteristic read or a notify.
///
/// - Note: Every `Characteristic` is [Observable](https://developer.apple.com/documentation/Observation) out of the box.
///     You can easily use the characteristic value within your SwiftUI view and the view will be automatically re-rendered
///     when the characteristic value is updated.
///
/// The below code example demonstrates declaring the Firmware Revision characteristic of the Device Information service.
///
/// ```swift
/// class DeviceInformationService: BluetoothService {
///    static let id = CBUUID(string: "180A")
///
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
///     ``CharacteristicAccessor/onChange(initial:perform:)-6ltwk`` or
///     ``CharacteristicAccessor/onChange(initial:perform:)-5awby``  to set up your action.
///
/// The below code example uses the [Bluetooth Heart Rate Service](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0)
/// to demonstrate the automatic notifications feature for the Heart Rate Measurement characteristic.
///
/// - Important: This closure is called from the Bluetooth Serial Executor, if you don't pass in an async method
///     that has an annotated actor isolation (e.g., `@MainActor` or actor isolated methods).
///
/// ```swift
/// class HeartRateService: BluetoothService {
///    static let id = CBUUID(string: "180D")
///
///     @Characteristic(id: "2A37", notify: true)
///     var heartRateMeasurement: HeartRateMeasurement?
///
///     init() {
///         $heartRateMeasurement.onChange(perform: processMeasurement)
///     }
///
///     func processMeasurement(_ measurement: HeartRateMeasurement) {
///         // process measurements ...
///     }
/// }
/// ```
///
/// ### Characteristic Interactions
///
/// To interact with a characteristic to read or write a value or enable or disable notifications,
/// you can use the ``projectedValue`` (`$` notation) to retrieve a temporary ``CharacteristicAccessor`` instance.
///
/// Do demonstrate this functionality, we completed the implementation of our Heart Rate Service
/// according to its [Specification](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0).
/// The example demonstrates reading and writing of characteristic values, controlling characteristic notifications,
/// and inspecting other properties like `isPresent`.
///
/// ```swift
/// class HeartRateService: BluetoothService {
///    static let id = CBUUID(string: "180D")
///
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
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-322p2``
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-6jfpk``
/// - ``init(wrappedValue:id:discoverDescriptors:)-1nome``
/// - ``init(wrappedValue:id:discoverDescriptors:)-1gflb``
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-6c95d``
/// - ``init(wrappedValue:id:notify:discoverDescriptors:)-6296j``
///
/// ### Inspecting a Characteristic
/// - ``CharacteristicAccessor/isPresent``
/// - ``CharacteristicAccessor/properties``
/// - ``CharacteristicAccessor/descriptors``
///
/// ### Reading a value
/// - ``CharacteristicAccessor/read()``
///
/// ### Writing a value
/// - ``CharacteristicAccessor/write(_:)``
/// - ``CharacteristicAccessor/writeWithoutResponse(_:)``
///
/// ### Controlling notifications
/// - ``CharacteristicAccessor/isNotifying``
/// - ``CharacteristicAccessor/enableNotifications(_:)``
///
/// ### Get notified about changes
/// - ``CharacteristicAccessor/onChange(initial:perform:)-6ltwk``
/// - ``CharacteristicAccessor/onChange(initial:perform:)-5awby``
///
/// ### Control Point Characteristics
/// - ``ControlPointCharacteristic``
/// - ``CharacteristicAccessor/sendRequest(_:timeout:)``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``CharacteristicAccessor``
@propertyWrapper
public final class Characteristic<Value>: @unchecked Sendable {
    class Configuration {
        let id: CBUUID
        let discoverDescriptors: Bool

        var defaultNotify: Bool

        /// Memory address as an identifier for this Characteristic instance.
        var objectId: ObjectIdentifier {
            ObjectIdentifier(self)
        }

        init(id: CBUUID, discoverDescriptors: Bool, defaultNotify: Bool) {
            self.id = id
            self.discoverDescriptors = discoverDescriptors
            self.defaultNotify = defaultNotify
        }
    }

    let configuration: Configuration
    private let _value: ObservableBox<Value?>
    private(set) var injection: CharacteristicPeripheralInjection<Value>?

    private let _testInjections = Box(CharacteristicTestInjections<Value>())

    var description: CharacteristicDescription {
        CharacteristicDescription(id: configuration.id, discoverDescriptors: configuration.discoverDescriptors)
    }

    /// Access the current characteristic value.
    ///
    /// This is either the last read value or the latest notified value.
    public var wrappedValue: Value? {
        _value.value
    }

    /// Retrieve a temporary accessors instance.
    ///
    /// This type allows you to interact with a Characteristic.
    ///
    /// - Note: The accessor captures the characteristic instance upon creation. Within the same `CharacteristicAccessor` instance
    ///     the view on the characteristic is consistent (characteristic exists vs. it doesn't, the underlying values themselves might still change).
    ///     However, if you project a new `CharacteristicAccessor` instance right after your access,
    ///     the view on the characteristic might have changed due to the asynchronous nature of SpeziBluetooth.
    public var projectedValue: CharacteristicAccessor<Value> {
        CharacteristicAccessor(configuration: configuration, injection: injection, value: _value, testInjections: _testInjections)
    }

    fileprivate init(wrappedValue: Value? = nil, characteristic: CBUUID, notify: Bool, discoverDescriptors: Bool = false) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.configuration = .init(id: characteristic, discoverDescriptors: discoverDescriptors, defaultNotify: notify)
        self._value = ObservableBox(wrappedValue)
    }


    func inject(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, serviceId: CBUUID, service: GATTService?) {
        let characteristic = service?.getCharacteristic(id: configuration.id)

        let injection = CharacteristicPeripheralInjection<Value>(
            bluetooth: bluetooth,
            peripheral: peripheral,
            serviceId: serviceId,
            characteristicId: configuration.id,
            value: _value,
            characteristic: characteristic
        )

        // mutual access with `CharacteristicAccessor/enableNotifications`
        self.injection = injection
        injection.assumeIsolated { injection in
            injection.setup(defaultNotify: configuration.defaultNotify)
        }
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
