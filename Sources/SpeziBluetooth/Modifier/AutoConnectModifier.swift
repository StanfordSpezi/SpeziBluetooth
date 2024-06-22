//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


extension View {
    /// Scan for nearby Bluetooth devices and auto connect.
    ///
    /// Scans for nearby Bluetooth devices till a device to auto connect to is discovered.
    /// Device scanning is automatically started again if the device happens to disconnect.
    ///
    /// Scans on nearby devices based on the ``Discover`` declarations provided in the initializer.
    ///
    /// All discovered devices for a given type can be accessed through the ``Bluetooth/nearbyDevices(for:)`` method.
    /// The first connected device can be accessed through the
    /// [Environment(_:)](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf) in your SwiftUI view.
    ///
    /// - Parameters:
    ///   - enabled: Flag indicating if nearby device scanning is enabled.
    ///   - bluetooth: The Bluetooth Module to use for scanning.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    /// - Returns: The modified view.
    public func autoConnect( // swiftlint:disable:this function_default_parameter_at_end
        enabled: Bool = true,
        with bluetooth: Bluetooth,
        minimumRSSI: Int = BluetoothManager.Defaults.defaultMinimumRSSI,
        advertisementStaleInterval: TimeInterval = BluetoothManager.Defaults.defaultStaleTimeout
    ) -> some View {
        scanNearbyDevices(enabled: enabled && !bluetooth.hasConnectedDevices, scanner: bluetooth, state: BluetoothModuleDiscoveryState(
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval,
            autoConnect: true
        ))
    }


    /// Scan for nearby Bluetooth devices and auto connect.
    ///
    /// Scans for nearby Bluetooth devices till a device to auto connect to is discovered.
    /// Device scanning is automatically started again if the device happens to disconnect.
    ///
    /// Scans on nearby devices based on the ``DiscoveryDescription`` provided in the initializer.
    /// All discovered devices can be accessed through the ``BluetoothManager/nearbyPeripherals`` property.
    ///
    /// - Parameters:
    ///   - enabled: Flag indicating if nearby device scanning is enabled.
    ///   - bluetoothManager: The Bluetooth Manager to use for scanning.
    ///   - discovery: The set of device description describing **how** and **what** to discover.
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second.
    /// - Returns: The modified view.
    public func autoConnect( // swiftlint:disable:this function_default_parameter_at_end
        enabled: Bool = true,
        with bluetoothManager: BluetoothManager,
        discovery: Set<DiscoveryDescription>,
        minimumRSSI: Int = BluetoothManager.Defaults.defaultMinimumRSSI,
        advertisementStaleInterval: TimeInterval = BluetoothManager.Defaults.defaultStaleTimeout
    ) -> some View {
        scanNearbyDevices(enabled: enabled && !bluetoothManager.hasConnectedDevices, scanner: bluetoothManager, state: BluetoothManagerDiscoveryState(
            configuredDevices: discovery,
            minimumRSSI: minimumRSSI,
            advertisementStaleInterval: advertisementStaleInterval,
            autoConnect: true
        ))
    }
}
