//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


public protocol BluetoothScanner {
    var state: BluetoothState { get }

    func scanNearbyDevices(autoConnect: Bool)

    func stopScanning()
}
