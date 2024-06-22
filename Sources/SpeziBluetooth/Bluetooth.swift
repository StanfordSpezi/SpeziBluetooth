//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OrderedCollections
import OSLog
import Spezi

// TODO: re-generate docc bundle!
// TODO: update code examples with scanNearbyDevices?


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
/// [`ByteEncodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/byteencodable),
/// [`ByteDecodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/1.0.0/documentation/bytecoding/bytedecodable) or
/// [`ByteCodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/bytecodable) respectively.
///
/// ```swift
/// class DeviceInformationService: BluetoothService {
///    static let id = CBUUID(string: "180A")
///
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
///     @Service var deviceInformation = DeviceInformationService()
///
///     @DeviceAction(\.connect)
///     var connect
///     @DeviceAction(\.disconnect)
///     var disconnect
///
///     required init() {}
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
///                 // In this case we search for some custom FFF0 service that is advertised.
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
/// You can use the ``SwiftUI/View/scanNearbyDevices(enabled:with:minimumRSSI:advertisementStaleInterval:autoConnect:)``
///  and ``SwiftUI/View/autoConnect(enabled:with:minimumRSSI:advertisementStaleInterval:)``
/// modifiers to scan for nearby devices and/or auto connect to the first available device. Otherwise, you can also manually start and stop scanning for nearby devices
/// using ``scanNearbyDevices(minimumRSSI:advertisementStaleInterval:autoConnect:)`` and ``stopScanning()``.
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
/// ### Integration with Spezi Modules
///
/// A Spezi [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module) is a great way of structuring your application into
/// different subsystems and provides extensive capabilities to model relationship and dependence between modules.
/// Every ``BluetoothDevice`` is a `Module`.
/// Therefore, you can easily access your SpeziBluetooth device from within any Spezi `Module` using the standard
/// [Module Dependency](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module-dependency) infrastructure. At the same time,
/// every `BluetoothDevice` can benefit from the same capabilities as every other Spezi `Module`.
///
/// Below is a short code example demonstrating how a `BluetoothDevice` uses the `@Dependency` property to interact with a Spezi Module that is
/// configured within the Spezi application.
///
/// ```swift
/// class Measurements: Module, EnvironmentAccessible, DefaultInitializable {
///     required init() {}
///
///     func recordNewMeasurement(_ measurement: WeightMeasurement) {
///         // ... process measurement
///     }
/// }
///
/// class MyDevice: BluetoothDevice {
///     @Service var weightScale = WeightScaleService()
///
///     // declare dependency to a configured Spezi Module
///     @Dependency var measurements: Measurements
///
///     required init() {
///         weightScale.$weightMeasurement.onChange(perform: handleNewMeasurement)
///     }
///
///     private func handleNewMeasurement(_ measurement: WeightMeasurement) {
///         measurements.recordNewMeasurement(measurement)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Configure the Bluetooth Module
/// - ``init(_:)``
/// - ``configuration``
///
/// ### Bluetooth State
/// - ``state``
/// - ``isScanning``
/// - ``stateSubscription``
///
/// ### Nearby Devices
/// - ``nearbyDevices(for:)``
/// - ``scanNearbyDevices(minimumRSSI:advertisementStaleInterval:autoConnect:)``
/// - ``stopScanning()``
///
/// ### Persistent Devices
/// - ``makePersistentDevice(for:as:)``
/// - ``makePersistentDevice(from:)``
///
/// ### Manually Manage Powered State
/// - ``powerOn()``
/// - ``powerOff()``
public actor Bluetooth: Module, EnvironmentAccessible, BluetoothActor {
    @Observable
    class Storage {
        var nearbyDevices: OrderedDictionary<UUID, any BluetoothDevice> = [:]
    }

    static let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "Bluetooth")

    /// The Bluetooth Executor from the underlying BluetoothManager.
    let bluetoothQueue: DispatchSerialQueue

    private let bluetoothManager: BluetoothManager

    /// The Bluetooth device configuration.
    ///
    /// Set of configured ``BluetoothDevice`` with their corresponding ``DiscoveryCriteria``.
    public nonisolated let configuration: Set<DeviceDiscoveryDescriptor>
    private let discoveryConfiguration: Set<DiscoveryDescription>

    private let _storage = Storage()

    private var logger: Logger {
        Self.logger
    }


    /// Represents the current state of Bluetooth.
    nonisolated public var state: BluetoothState {
        bluetoothManager.state
    }

    /// Subscribe to changes of the `state` property.
    ///
    /// Creates an `AsyncStream` that yields all **future** changes to the ``state`` property.
    public var stateSubscription: AsyncStream<BluetoothState> {
        bluetoothManager.assumeIsolated { manager in
            manager.stateSubscription
        }
    }

    /// Whether or not we are currently scanning for nearby devices.
    nonisolated public var isScanning: Bool {
        bluetoothManager.isScanning
    }

    /// Support for the auto connect modifier.
    @_documentation(visibility: internal)
    nonisolated public var hasConnectedDevices: Bool {
        bluetoothManager.hasConnectedDevices
    }


    private var nearbyDevices: OrderedDictionary<UUID, any BluetoothDevice> {
        get {
            _storage.nearbyDevices
        }
        set {
            _storage.nearbyDevices = newValue
        }
    }

    /// Nearby devices that should be retained as persistent devices.
    ///
    /// Devices that are currently in the list of nearby devices but shouldn't be cleared once they leave the nearby devices list as
    /// they have been converted to a persistent device using ``makePersistentDevice(from:)``.
    private var nearbyDevicesFlaggedForPersistence: Set<UUID> = []

    @Application(\.spezi)
    private var spezi

    /// Stores the connected device instance for every configured ``BluetoothDevice`` type.
    @Model private var connectedDevicesModel = ConnectedDevices()
    /// Injects the ``BluetoothDevice`` instances from the `ConnectedDevices` model into the SwiftUI environment.
    @Modifier private var devicesInjector: ConnectedDevicesEnvironmentModifier


    /// Configure the Bluetooth Module.
    ///
    /// Configures the Bluetooth Module with the provided set of ``DeviceDiscoveryDescriptor``s.
    /// Below is a short code example on how you would discover a `ExampleDevice` by its advertised service id.
    ///
    /// ```swift
    /// Bluetooth {
    ///     Discover(ExampleDevice.self, by: .advertisedService(MyExampleService.self))
    /// }
    /// ```
    ///
    /// - Parameter devices: The set of configured devices.
    public init(
        @DiscoveryDescriptorBuilder _ devices: @Sendable () -> Set<DeviceDiscoveryDescriptor>
    ) {
        let configuration = devices()
        let deviceTypes = configuration.deviceTypes

        let discovery = ClosureRegistrar.$writeableView.withValue(.init()) {
            // we provide a closure registrar just to silence any out-of-band usage warnings!
            configuration.parseDiscoveryDescription()
        }

        let bluetoothManager = BluetoothManager()

        self.bluetoothQueue = bluetoothManager.bluetoothQueue
        self.bluetoothManager = bluetoothManager
        self.configuration = configuration
        self.discoveryConfiguration = discovery
        self._devicesInjector = Modifier(wrappedValue: ConnectedDevicesEnvironmentModifier(configuredDeviceTypes: deviceTypes))

        Task {
            await self.observeDiscoveredDevices()
        }
    }

    /// Request to power up the Bluetooth Central.
    ///
    /// This method manually instantiates the underlying Central Manager and ensure that it stays allocated.
    /// Balance this call with a call to ``powerOff()``.
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission prompts to the latest possible moment avoiding to unexpectedly display power alerts.
    public func powerOn() {
        bluetoothManager.assumeIsolated { manager in
            manager.powerOn()
        }
    }

    /// Request to power down the Bluetooth Central.
    ///
    /// This method request to power off the central. This is delay if the central is still used (e.g., currently scanning or connected peripherals).
    ///
    /// - Note : The underlying `CBCentralManager` is lazily allocated and deallocated once it isn't needed anymore.
    ///     This is used to delay Bluetooth permission prompts to the latest possible moment avoiding to unexpectedly display power alerts.
    public func powerOff() {
        bluetoothManager.assumeIsolated { manager in
            manager.powerOff()
        }
    }

    private func observeDiscoveredDevices() {
        self.assertIsolated("This didn't move to the actor even if it should.")
        bluetoothManager.assumeIsolated { manager in
            manager.onChange(of: \.discoveredPeripherals) { [weak self] discoveredDevices in
                guard let self = self else {
                    return
                }

                self.assertIsolated("BluetoothManager peripherals change closure was unexpectedly not called on the Bluetooth SerialExecutor.")
                self.assumeIsolated { bluetooth in
                    bluetooth.observeDiscoveredDevices()
                    bluetooth.handleUpdatedNearbyDevicesChange(discoveredDevices)
                }
            }

            // we currently do not track the `retrievedPeripherals` collection of the BluetoothManager. The assumption is that
            // `retrievePeripheral` is always called through the `Bluetooth` module so we are aware of everything anyways.
            // And we don't care about the rest.
        }
    }

    private func observePeripheralState(of uuid: UUID) {
        // We must make sure that we don't capture the `peripheral` within the `onChange` closure as otherwise
        // this would require a reference cycle within the `BluetoothPeripheral` class.
        // Therefore, we have this indirection via the uuid here.
        guard let peripheral = bluetoothManager.assumeIsolated({ $0.knownPeripherals[uuid] }) else {
            return
        }

        peripheral.assumeIsolated { peripheral in
            peripheral.onChange(of: \.state) { [weak self] _ in
                guard let self = self else {
                    return
                }

                self.assumeIsolated { bluetooth in
                    bluetooth.observePeripheralState(of: uuid)
                    bluetooth.handlePeripheralStateChange()
                }
            }
        }
    }

    private func handleUpdatedNearbyDevicesChange(_ discoveredDevices: OrderedDictionary<UUID, BluetoothPeripheral>) {
        var checkForConnected = false

        // remove all delete keys
        for key in nearbyDevices.keys where discoveredDevices[key] == nil {
            checkForConnected = true
            let device = nearbyDevices.removeValue(forKey: key)

            if let device, !nearbyDevicesFlaggedForPersistence.contains(key) {
                releaseDevice(device, with: key)
            }
        }

        // add devices for new keys
        for (uuid, peripheral) in discoveredDevices where nearbyDevices[uuid] == nil {
            let advertisementData = peripheral.advertisementData
            guard let configuration = configuration.find(for: advertisementData, logger: logger) else {
                logger.warning("Ignoring peripheral \(peripheral.debugDescription) that cannot be mapped to a device class.")
                continue
            }

            let device = prepareDevice(configuration.deviceType, peripheral: peripheral)
            nearbyDevices[uuid] = device

            checkForConnected = true
        }

        if checkForConnected {
            // ensure that we get notified about, e.g., a connected peripheral that is instantly removed
            handlePeripheralStateChange()
        }
    }

    private func handlePeripheralStateChange() {
        // check for active connected device
        let connectedDevices = bluetoothManager.assumeIsolated { $0.knownPeripherals }
            .filter { _, value in
                value.assumeIsolated { $0.state } == .connected
            }
            .compactMap { key, _ in
                // TODO: we need a set of persistent devices!
                (key, nearbyDevices[key]) // map them to their devices class
            }
            .reduce(into: [:]) { result, tuple in
                result[tuple.0] = tuple.1
            }

        let connectedDevicesModel = connectedDevicesModel
        Task { @MainActor in
            connectedDevicesModel.update(with: connectedDevices)
        }
    }

    /// Retrieve nearby devices.
    ///
    /// Use this method to retrieve nearby discovered Bluetooth peripherals. This method will only
    /// return nearby devices that are of the provided ``BluetoothDevice`` type.
    /// - Parameter device: The device type to filter for.
    /// - Returns: A list of nearby devices of a given ``BluetoothDevice`` type.
    public nonisolated func nearbyDevices<Device: BluetoothDevice>(for device: Device.Type = Device.self) -> [Device] {
        _storage.nearbyDevices.values.compactMap { device in
            device as? Device
        }
    }


    // TODO: docs
    public func makePersistentDevice<Device: BluetoothDevice>(
        for uuid: UUID,
        as device: Device.Type = Device.self
    ) async -> PersistentDevice<Device>? {
        if let anyNearbyDevice = nearbyDevices[uuid] {
            guard let nearbyDevice = anyNearbyDevice as? Device else {
                preconditionFailure("""
                                    Tried to make persistent device for nearby device with differing types. \
                                    Found \(type(of: anyNearbyDevice)), requested \(Device.self)
                                    """)
            }
            return makePersistentDevice(from: nearbyDevice)
        }

        // This condition is fine, every device type that wants to be paired has to be discovered at least once.
        // This helps also with building the `ConnectedDevices` statically and have the SwiftUI view hierarchy not re-rendered every time.
        precondition(
            configuration.contains(where: { $0.deviceType == device }),
            "Tried to make persistent device for non-configured device class \(Device.self)"
        )

        let configuration = ClosureRegistrar.$writeableView.withValue(.init()) {
            // we provide a closure registrar just to silence any out-of-band usage warnings!
            device.parseDeviceDescription()
        }

        guard let peripheral = await bluetoothManager.retrievePeripheral(for: uuid, with: configuration) else {
            return nil
        }


        let device = prepareDevice(Device.self, peripheral: peripheral)


        observePeripheralState(of: uuid) // ensure we observe state changes of these devices!
        handlePeripheralStateChange() // ensure that we get notified about, e.g., a connected peripheral that is instantly removed

        // The semantics of retrievePeripheral is as follows: it returns a BluetoothPeripheral that is weakly allocated by the BluetoothManager.´
        // Therefore, the BluetoothPeripheral is owned by the caller and is automatically deallocated if the caller decides to not require the instance anymore.
        // We want to replicate this behavior with the Bluetooth Module as well, however `BluetoothDevice`s do have reference cycles and require explicit
        // deallocation. Therefore, we introduce this helper RAII structure `PersistentDevice` that equally moves into the ownership of the caller.
        // If they happen to release their reference, the deinit of the class is called informing the Bluetooth Module of de-initialization, allowing us
        // to clean up the underlying BluetoothDevice instance (removing all self references) and therefore allowing to deinit the underlying BluetoothPeripheral.
        return PersistentDevice(self, device, uuid) // RAII
    }

    public func makePersistentDevice<Device: BluetoothDevice>(from device: Device) -> PersistentDevice<Device> { // TODO: docs
        guard let (id, _) = nearbyDevices.first(where: { _, value in
            ObjectIdentifier(value) == ObjectIdentifier(device)
        }) else {
            preconditionFailure("Tried to convert device to persistent device for a device we couldn't locate in the list of nearby devices.")
        }

        nearbyDevicesFlaggedForPersistence.insert(id)

        return PersistentDevice(self, device, id)
    }

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``Discover`` declarations provided in the initializer.
    ///
    /// All discovered devices for a given type can be accessed through the ``nearbyDevices(for:)`` method.
    /// The first connected device can be accessed through the
    /// [Environment(_:)](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf) in your SwiftUI view.
    ///
    /// - Tip: Scanning for nearby devices can easily be managed via the ``SwiftUI/View/scanNearbyDevices(enabled:with:minimumRSSI:advertisementStaleInterval:autoConnect:)``
    ///     modifier.
    ///
    /// - Parameters:
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    public func scanNearbyDevices(
        minimumRSSI: Int = BluetoothManager.Defaults.defaultMinimumRSSI,
        advertisementStaleInterval: TimeInterval = BluetoothManager.Defaults.defaultStaleTimeout,
        autoConnect: Bool = false
    ) {
        bluetoothManager.assumeIsolated { manager in
            manager.scanNearbyDevices(
                discovery: discoveryConfiguration,
                minimumRSSI: minimumRSSI,
                advertisementStaleInterval: advertisementStaleInterval,
                autoConnect: autoConnect
            )
        }
    }

    /// Stop scanning for nearby bluetooth devices.
    public func stopScanning() {
        bluetoothManager.assumeIsolated { manager in
            manager.stopScanning()
        }
    }
}


extension Bluetooth: BluetoothScanner {
    func scanNearbyDevices(_ state: BluetoothModuleDiscoveryState) {
        scanNearbyDevices(
            minimumRSSI: state.minimumRSSI,
            advertisementStaleInterval: state.advertisementStaleInterval,
            autoConnect: state.autoConnect
        )
    }

    func updateScanningState(_ state: BluetoothModuleDiscoveryState) {
        let managerState = BluetoothManagerDiscoveryState(
            configuredDevices: discoveryConfiguration,
            minimumRSSI: state.minimumRSSI,
            advertisementStaleInterval: state.advertisementStaleInterval,
            autoConnect: state.autoConnect
        )

        bluetoothManager.assumeIsolated { manager in
            manager.updateScanningState(managerState)
        }
    }
}

// MARK: - Device Handling

extension Bluetooth {
    func prepareDevice<Device: BluetoothDevice>(_ device: Device.Type, peripheral: BluetoothPeripheral) -> Device {
        let closures = ClosureRegistrar()
        let device = ClosureRegistrar.$writeableView.withValue(closures) {
            device.init()
        }
        ClosureRegistrar.$readableView.withValue(closures) {
            device.inject(peripheral: peripheral)
        }

        observePeripheralState(of: peripheral.id) // register \.state onChange closure

        spezi.loadModule(device) // TODO: spezi currently only allows one module of a type!!!!

        return device
    }

    func releaseDevice(_ device: some BluetoothDevice, with id: UUID) {
        nearbyDevicesFlaggedForPersistence.remove(id)
        device.clearState(isolatedTo: self)
        spezi.unloadModule(device)
    }
}

// swiftlint:disable:this file_length
