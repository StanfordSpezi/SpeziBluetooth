//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog
import Spezi

// TODO: extension to CBUUID for common ids?


// TODO: "Enable applications to connect to Bluetooth devices using modern programming paradigms."???

/// Enable applications to connect to Bluetooth devices.
///
/// ## Topics
///
/// ### Configure the Bluetooth Module
/// - ``init(minimumRSSI:advertisementStaleInterval:_:)``
///
/// ### Bluetooth State
/// - ``state``
/// - ``isScanning``
///
/// ### Nearby Devices
/// - ``nearbyDevices(for:)``
/// - ``scanNearbyDevices(autoConnect:)``
/// - ``stopScanning()``
@Observable
public class Bluetooth: Module, EnvironmentAccessible, BluetoothScanner {
    static let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "Bluetooth")

    private let bluetoothManager: BluetoothManager
    private let deviceConfigurations: Set<DiscoveryConfiguration>

    private var logger: Logger {
        Self.logger
    }


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
    @Modifier @ObservationIgnored private var devicesInjector: ConnectedDevicesEnvironmentModifier


    /// TODO: docs!
    /// - Parameters:
    ///   - minimumRSSI:
    ///   - advertisementStaleInterval:
    ///   - devices:
    public init(
        minimumRSSI: Int = BluetoothManager.Defaults.defaultMinimumRSSI,
        advertisementStaleInterval: TimeInterval = BluetoothManager.Defaults.defaultStaleTimeout,
        @DiscoveryConfigurationBuilder _ devices: () -> Set<DiscoveryConfiguration>
    ) {
        let configuration = devices()
        let deviceTypes = configuration.deviceTypes

        // TODO: if a device class doesn't specify anything, EVERYTHING is getting discovered!
        self.bluetoothManager = BluetoothManager(
            devices: configuration.parseDeviceDescription(),
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval
        )
        self.deviceConfigurations = configuration
        self._devicesInjector = Modifier(wrappedValue: ConnectedDevicesEnvironmentModifier(configuredDeviceTypes: deviceTypes))

        observeNearbyDevices() // register observation tracking
    }

    private func observeNearbyDevices() {
        withObservationTracking {
            _ = bluetoothManager.discoveredPeripherals
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleNearbyDevicesChange()
            }
            self?.observeNearbyDevices()
        }
    }

    private func observePeripheralState(of uuid: UUID) {
        // We must make sure that we don't capture the `peripheral` within the `onChange` closure as otherwise
        // this would require a reference cycle within the `BluetoothPeripheral` class.
        // Therefore, we have this indirection via the uuid here.
        guard let peripheral = bluetoothManager.discoveredPeripherals[uuid] else {
            return
        }

        withObservationTracking {
            _ = peripheral.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.handlePeripheralStateChange()
            }

            self?.observePeripheralState(of: uuid)
        }
    }

    @MainActor
    private func handleNearbyDevicesChange() {
        let discoveredDevices = bluetoothManager.discoveredPeripherals

        var checkForConnected = false

        // remove all delete keys
        for key in nearbyDevices.keys where discoveredDevices[key] == nil {
            checkForConnected = true
            nearbyDevices.removeValue(forKey: key)
        }

        // add devices for new keys
        for (uuid, peripheral) in discoveredDevices where nearbyDevices[uuid] == nil {
            guard let configuration = deviceConfigurations.find(for: peripheral.advertisementData, logger: logger) else {
                // TODO: replace peripheral.cbPeripheral.debugIdentifier with peripheral.debugIdentifier
                logger.warning("Ignoring peripheral \(peripheral.cbPeripheral.debugIdentifier) that cannot be mapped to a device class.")
                continue
            }

            let device = configuration.anyDeviceType.init()
            device.inject(peripheral: peripheral)
            nearbyDevices[uuid] = device

            checkForConnected = true
            observePeripheralState(of: uuid)
        }

        if checkForConnected {
            // ensure that we get notified about, e.g., a connected peripheral that is instantly removed
            handlePeripheralStateChange()
        }
    }

    @MainActor
    private func handlePeripheralStateChange() {
        // check for active connected device
        let connectedDevices = bluetoothManager.discoveredPeripherals
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

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``Discover`` declarations provided in the initializer.
    ///
    /// All discovered devices for a given type can be accessed through the ``nearbyDevices(for:)`` method.
    /// The first connected device can be accessed through the
    /// [Environment(_:)](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf) in your SwiftUI view.
    ///
    /// - Note: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(with:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameter autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    public func scanNearbyDevices(autoConnect: Bool = false) {
        bluetoothManager.scanNearbyDevices(autoConnect: autoConnect)
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() {
        bluetoothManager.stopScanning()
    }
}
