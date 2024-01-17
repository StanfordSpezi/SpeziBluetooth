//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


public protocol BluetoothDevice: AnyObject {
    // TODO: somehow allow access to general device state (connected?, name?, undlerying CBPeripheral?)
    init()
}
