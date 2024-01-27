//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// Describes the state of a Bluetooth peripheral.
public enum PeripheralState: UInt8 {
    /// The peripheral is disconnected.
    case disconnected
    /// The peripheral is currently establishing a connection.
    case connecting // TODO: make this the state when we are still discovering services and characteristics and descriptors?
    /// The peripheral is connected.
    case connected
    /// The peripheral is currently disconnecting.
    case disconnecting
}


extension PeripheralState: CustomStringConvertible, Sendable {
    public var description: String {
        switch self {
        case .disconnected:
            "disconnected"
        case .connecting:
            "connecting"
        case .connected:
            "connected"
        case .disconnecting:
            "disconnecting"
        }
    }
}


extension PeripheralState {
    init(from state: CBPeripheralState) {
        switch state {
        case .disconnected:
            self = .disconnected
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .disconnecting:
            self = .disconnecting
        @unknown default:
            self = .disconnected
        }
    }
}
