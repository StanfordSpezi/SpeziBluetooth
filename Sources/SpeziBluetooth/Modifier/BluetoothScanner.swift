//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Any kind of Bluetooth Scanner.
protocol BluetoothScanner: Identifiable where ID: Hashable {
    /// Captures state required to start scanning.
    associatedtype ScanningState: Equatable

    /// Indicates if there is at least one connected peripheral.
    ///
    /// Make sure this tracks observability of all devices.
    var hasConnectedDevices: Bool { get }

    /// Scan for nearby bluetooth devices.
    ///
    /// How devices are discovered and how they can be accessed is implementation defined.
    ///
    /// - Parameter state: The scanning state.
    func scanNearbyDevices(_ state: ScanningState) async

    /// Update the `ScanningState` for an currently ongoing scanning session.
    func updateScanningState(_ state: ScanningState) async

    /// Stop scanning for nearby bluetooth devices.
    func stopScanning() async
}
