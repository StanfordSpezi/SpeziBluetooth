//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Any kind of Bluetooth Scanner.
public protocol BluetoothScanner {
    /// The current state of the bluetooth scanner.
    var state: BluetoothState { get }

    /// Scan for nearby bluetooth devices.
    ///
    /// How devices are discovered and how they can be accessed is implementation defined.
    ///
    /// - Parameter autoConnect: If enabled, the bluetooth manager will automatically connect to
    ///     the nearby device if only one is found for a given time threshold.
    func scanNearbyDevices(autoConnect: Bool)

    /// Stop scanning for nearby bluetooth devices.
    func stopScanning()
}