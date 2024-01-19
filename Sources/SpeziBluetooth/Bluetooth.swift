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
public class Bluetooth: Module, EnvironmentAccessible, BluetoothScanner {
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

    /// Stores the connected device instance for every configured ``BluetoothDevice`` type.
    @Model @ObservationIgnored  private var connectedDevicesModel = ConnectedDevices()
    /// Injects the ``BluetoothDevice`` instances from the `ConnectedDevices` model into the SwiftUI environment.
    @Modifier @ObservationIgnored private var devicesInjector: ConnectedDevicesInjector
    // TODO: how to provide access to the nearby devices list?


    // TODO: duplication of default values; + support other configurations as well!
    public init(minimumRSSI: Int = -65, @DeviceConfigurationBuilder _ devices: () -> Set<DeviceConfiguration>) {
        let configuration = devices()

        self.bluetoothManager = BluetoothManager(discovery: Set(configuration.map { $0.parseDiscoveryConfiguration() }))
        self.deviceConfigurations = configuration // TODO: when to init the devices?

        // TODO: pass device types!
        self._devicesInjector = Modifier(wrappedValue: ConnectedDevicesInjector(configuredDeviceTypes: []))

        observeNearbyDevices()
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

        // check for active connected device
        let connectedDevices = discoveredDevices
            .filter { _, value in
                value.state == .connected
            }
            .compactMap { key, _ in
                (key, nearbyDevices[key]) // map them to their devices class
            }
            .reduce(into: [:]) { result, tuple in
                result[tuple.0] = tuple.1
            }

        self.connectedDevicesModel.update(with: connectedDevices)
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

@Observable
private class ConnectedDevices {
    @MainActor private var connectedDevices: [ObjectIdentifier: BluetoothDevice] = [:]
    @MainActor private var connectedDeviceIds: [ObjectIdentifier: UUID] = [:]

    
    @MainActor
    func update(with devices: [UUID: BluetoothDevice]) {
        // remove devices that disconnected
        for (identifier, uuid) in connectedDeviceIds where devices[uuid] == nil {
            connectedDeviceIds.removeValue(forKey: identifier)
            connectedDevices.removeValue(forKey: identifier)
        }

        // add newly connected devices that are not injected yet
        for (uuid, device) in devices {
            guard connectedDevices[device.typeIdentifier] == nil else {
                continue // already present, we just inject the first device of a particular type into the environment
            }

            // Newly connected device for a type that isn't present yet. Save both device and id.
            connectedDevices[device.typeIdentifier] = device
            connectedDeviceIds[device.typeIdentifier] = uuid
        }
    }

    @MainActor
    subscript(_ identifier: ObjectIdentifier) -> BluetoothDevice? {
        connectedDevices[identifier]
    }
}


import SwiftUI // TODO: adjust
private struct ConnectedDevicesInjector: ViewModifier {
    private let configuredDeviceTypes: [BluetoothDevice.Type]

    @Environment(ConnectedDevices.self)
    var connectedDevices


    init(configuredDeviceTypes: [BluetoothDevice.Type]) {
        self.configuredDeviceTypes = configuredDeviceTypes
    }


    func body(content: Content) -> some View {
        injectConnectedDevices(into: AnyView(content))
    }

    @MainActor
    private func injectConnectedDevices(into view: AnyView) -> AnyView {
        var view = view

        for configuredDeviceType in configuredDeviceTypes {
            view = configuredDeviceType.inject(into: view, connected: connectedDevices)
        }

        return view
    }
}


extension BluetoothDevice {
    var typeIdentifier: ObjectIdentifier {
        ObjectIdentifier(Self.self)
    }

    @MainActor
    fileprivate static func inject(into content: AnyView, connected: ConnectedDevices) -> AnyView {
        if let connectedDeviceAny = connected[ObjectIdentifier(Self.self)],
           let connectedDevice = connectedDeviceAny as? Self {
            // TODO: logger all the way?
            AnyView(content.environment(connectedDevice))
        } else {
            content
        }
    }
}
