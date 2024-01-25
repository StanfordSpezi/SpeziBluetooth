//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog
import Spezi


/// Connect and communicate with Bluetooth devices using modern programming paradigms.
///
/// This module allows to connect and communicate with Bluetooth devices using modern programming paradigms.
/// Under the hood this module uses Apple's [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)
/// through the ``BluetoothManager``.
///
/// ### Create your Bluetooth device
///
/// The Bluetooth module allows to declarative define your Bluetooth device using a ``BluetoothDevice`` implementation and property wrappers
/// like ``Service`` and ``Characteristic``.
///
/// The below code examples demonstrate how you can implement your own Bluetooth device.
///
/// First of all we define our Bluetooth service by implementing a ``BluetoothService``.
/// We use the ``Characteristic`` property wrapper to declare its characteristics.
/// Note that the value types needs to be optional and conform to ``ByteEncodable``, ``ByteDecodable`` or ``ByteCodable`` respectively.
///
/// ```swift
/// class DeviceInformationService: BluetoothService {
///     @Characteristic(id: "2A29")
///     var manufacturer: String?
///     @Characteristic(id: "2A26")
///     var firmwareRevision: String?
/// }
/// ```
///
/// We can use this Bluetooth service now in the `MyDevice` implementation as follows.
///
/// - Tip: We use the ``DeviceState`` and ``DeviceAction`` property wrappers to get access to the device state and its actions. Those two
///     property wrappers can also be used within a ``BluetoothService`` type.
///
/// ```swift
/// class MyDevice: BluetoothDevice {
///     @DeviceState(\.id)
///     var id: UUID
///     @DeviceState(\.name)
///     var name: String?
///     @DeviceState(\.state)
///     var state: PeripheralState
///
///     @Service(id: "180A")
///     var deviceInformation = DeviceInformationService()
///
///     @DeviceAction(\.connect)
///     var connect
///     @DeviceAction(\.disconnect)
///     var disconnect
///
///     init() {} // required initializer
/// }
/// ```
///
/// ### Configure the Bluetooth Module
///
/// We use the above `BluetoothDevice` implementation to configure the `Bluetooth` module within the
/// [SpeziAppDelegate](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).
///
/// ```swift
/// import Spezi
///
/// class ExampleDelegate: SpeziAppDelegate {
///     override var configuration: Configuration {
///         Configuration {
///             Bluetooth {
///                 // Define which devices type to discover by what criteria .
///                 // In this case we search for some custom FFF0 characteristic that is advertised.
///                 Discover(MyDevice.self, by: .advertisedService("FFF0"))
///             }
///         }
///     }
/// }
/// ```
///
/// ### Using the Bluetooth Module
///
/// Once you have the `Bluetooth` module configured within your Spezi app, you can access the module within your
/// [`Environment`](https://developer.apple.com/documentation/swiftui/environment).
///
/// You can use the ``SwiftUI/View/scanNearbyDevices(enabled:with:autoConnect:)`` and ``SwiftUI/View/autoConnect(enabled:with:)``
/// modifiers to scan for nearby devices and/or auto connect to the first available device. Otherwise, you can also manually start and stop scanning for nearby devices
/// using ``scanNearbyDevices(autoConnect:)`` and ``stopScanning()``.
///
/// To retrieve the list of nearby devices you may use ``nearbyDevices(for:)``.
///
/// > Tip: To easily access the first connected device, you can just query the SwiftUI Environment for your `BluetoothDevice` type.
///     Make sure to declare the property as optional using the respective [`Environment(_:)`](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf)
///     initializer.
///
/// The below code example demonstrates all these steps of retrieving the `Bluetooth` module from the environment, listing all nearby devices,
/// auto connecting to the first one and displaying some basic information of the currently connected device.
///
/// ```swift
/// import SpeziBluetooth
/// import SwiftUI
///
/// struct MyView: View {
///     @Environment(Bluetooth.self)
///     var bluetooth
///     @Environment(MyDevice.self)
///     var myDevice: MyDevice?
///
///     var body: some View {
///         List {
///             if let myDevice {
///                 Section {
///                     Text("Device")
///                     Spacer()
///                     Text("\(myDevice.state.description)")
///                 }
///             }
///
///             Section {
///                 ForEach(bluetooth.nearbyDevices(for: MyDevice.self), id: \.id) { device in
///                     Text("\(device.name ?? "unknown")")
///                 }
///             } header: {
///                 HStack {
///                     Text("Devices")
///                         .padding(.trailing, 10)
///                     if bluetooth.isScanning {
///                         ProgressView()
///                     }
///                 }
///             }
///         }
///             .scanNearbyDevices(with: bluetooth, autoConnect: true)
///     }
/// }
/// ```
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

    /// Whether or not we are currently scanning for nearby devices.
    public var isScanning: Bool {
        bluetoothManager.isScanning
    }

    @_documentation(visibility: internal)
    public var hasConnectedDevices: Bool {
        bluetoothManager.hasConnectedDevices
    }


    @MainActor private var nearbyDevices: [UUID: BluetoothDevice] = [:]

    /// Stores the connected device instance for every configured ``BluetoothDevice`` type.
    @Model @ObservationIgnored  private var connectedDevicesModel = ConnectedDevices()
    /// Injects the ``BluetoothDevice`` instances from the `ConnectedDevices` model into the SwiftUI environment.
    @Modifier @ObservationIgnored private var devicesInjector: ConnectedDevicesEnvironmentModifier


    /// Configure the Bluetooth Module.
    ///
    /// Configures the Bluetooth Module with the provided set of ``DiscoveryConfiguration``s.
    /// Below is a short code example on how you would discover a `ExampleDevice` by its advertised service id.
    ///
    /// ```swift
    /// Bluetooth {
    ///     Discover(ExampleDevice.self, by: .advertisedService("..."))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    ///   - devices:
    public init(
        minimumRSSI: Int = BluetoothManager.Defaults.defaultMinimumRSSI,
        advertisementStaleInterval: TimeInterval = BluetoothManager.Defaults.defaultStaleTimeout,
        @DiscoveryConfigurationBuilder _ devices: () -> Set<DiscoveryConfiguration>
    ) {
        let configuration = devices()
        let deviceTypes = configuration.deviceTypes

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
            let device = nearbyDevices.removeValue(forKey: key)
            device?.clearState()
        }

        // add devices for new keys
        for (uuid, peripheral) in discoveredDevices where nearbyDevices[uuid] == nil {
            guard let configuration = deviceConfigurations.find(for: peripheral.advertisementData, logger: logger) else {
                logger.warning("Ignoring peripheral \(peripheral.debugDescription) that cannot be mapped to a device class.")
                continue
            }


            ClosureRegistrar.$instance.withValue(ClosureRegistrar()) {
                let device = configuration.anyDeviceType.init()
                device.inject(peripheral: peripheral)
                nearbyDevices[uuid] = device
            }

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

    /// Retrieve nearby devices.
    ///
    /// Use this method to retrieve nearby discovered Bluetooth peripherals. This method will only
    /// return nearby devices that are of the provided ``BluetoothDevice`` type.
    /// - Parameter device: The device type to filter for.
    /// - Returns: A list of nearby devices of a given ``BluetoothDevice`` type.
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
    /// - Tip: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(enabled:with:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameter autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    public func scanNearbyDevices(autoConnect: Bool = false) async {
        await bluetoothManager.scanNearbyDevices(autoConnect: autoConnect)
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() async {
        await bluetoothManager.stopScanning()
    }
}
