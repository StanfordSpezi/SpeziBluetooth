//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi

// TODO: extension to CBUUID for common ids?


// TODO: "Enable applications to connect to Bluetooth devices using modern programming paradigms."???

/// Enable applications to connect to Bluetooth devices.
///
/// > Important: If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/setup) to setup the core Spezi infrastructure.
///
/// The module needs to be registered in a Spezi-based application using the [`configuration`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate/configuration)
/// in a [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate):
/// ```swift
/// class ExampleAppDelegate: SpeziAppDelegate {
///     override var configuration: Configuration {
///         Configuration {
///             Bluetooth(services: [/* ... */])
///             // ...
///         }
///     }
/// }
/// ```
/// > Tip: You can learn more about a [`Module` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module).
///
/// You will have to ensure that the ``Bluetooth`` module is correctly set up with the right services, e.g., as shown in the example shown in the <doc:SpeziBluetooth> documentation.
///
/// ## Usage
///
/// The most common usage of the ``Bluetooth`` module is using it as a dependency using the [`@Dependency`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module/dependency) property wrapper within an other Spezi [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module).
///
/// [You can learn more about the Spezi dependency injection mechanisms in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module-dependency).
///
/// The following example demonstrates the usage of this mechanism.
/// ```swift
/// class BluetoothExample: Module, BluetoothMessageHandler {
///     @Dependency private var bluetooth: Bluetooth
///
///
///     /// The current Bluetooth connection state.
///     var bluetoothState: BluetoothState {
///         bluetooth.state
///     }
///     
///
///     // ...
///
///     
///     /// Configuration method to register the `BluetoothExample` as a ``BluetoothNotificationHandler`` for the Bluetooth module.
///     func configure() {
///         bluetooth.add(messageHandler: self)
///     }
///     
///     
///     /// Sends a string message over Bluetooth.
///     ///
///     /// - Parameter information: The string message to be sent.
///     func send(information: String) async throws {
///         try await bluetooth.write(
///             Data(information.utf8),
///             service: Self.exampleService.serviceUUID,
///             characteristic: Self.exampleCharacteristic
///         )
///     }
///     
///     func receive(_ data: Data, service: CBUUID, characteristic: CBUUID) {
///         // ...
///     }
/// }
/// ```
///
/// > Tip: You can find a more extensive example in the main <doc:SpeziBluetooth> documentation.
@Observable
public class Bluetooth: Module {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "Bluetooth")
    private let bluetoothManager: BluetoothManager
    private let deviceConfigurations: Set<DeviceConfiguration> // TODO: index by type?


    /// Represents the current state of Bluetooth.
    public var state: BluetoothState {
        bluetoothManager.state
    }

    public var isScanning: Bool {
        bluetoothManager.isScanning
    }


    @MainActor private var nearbyDevices: [UUID: BluetoothDevice] = [:]

    // TODO: how to provide access to the nearby devices list?


    // TODO: duplication of default values; + support other configurations as well!
    public init(minimumRSSI: Int = -65, @DeviceConfigurationBuilder _ devices: () -> Set<DeviceConfiguration>) {
        let configuration = devices()

        self.bluetoothManager = BluetoothManager(discovery: Set(configuration.map { $0.parseDiscoveryConfiguration() }))
        self.deviceConfigurations = configuration // TODO: when to init the devices?

        // TODO: for each "Discover" entry, inject a nearby devices list for this type and a connected devices optional?
    }

    private func observeNearbyDevices() {
        withObservationTracking {
            _ = bluetoothManager.nearbyPeripheralsView
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleNearbyDevicesChange()
            }
            self?.observeNearbyDevices()
        }
    }

    @MainActor
    private func handleNearbyDevicesChange() {
        let discoveredDevices = bluetoothManager.discoveredPeripherals

        // remove all delete keys
        for key in nearbyDevices.keys where discoveredDevices[key] == nil {
            nearbyDevices.removeValue(forKey: key)
        }

        // add devices for new keys
        for (key, peripheral) in discoveredDevices where nearbyDevices[key] == nil {
            guard let configuration = deviceConfigurations.find(for: peripheral.advertisementData, logger: logger) else {
                // TODO: just ignore but do the logger?
                continue
            }

            let device = configuration.anyDeviceType.init()
            device.inject(peripheral: peripheral)
            nearbyDevices[key] = device
        }
    }

    @MainActor
    public func nearbyDevices<Device: BluetoothDevice>(for device: Device.Type = Device.self) -> [Device] {
        nearbyDevices.values.compactMap { device in
            device as? Device
        }
    }

    // TODO: make BluetoothDeviceScanner protocol for both methods below (+ modifier implementation)

    public func scanNearbyDevices(autoConnect: Bool = false) { // TODO copy docs
        bluetoothManager.scanNearbyDevices(autoConnect: autoConnect)
    }

    public func stopScanning() {
        bluetoothManager.stopScanning()
    }
}
