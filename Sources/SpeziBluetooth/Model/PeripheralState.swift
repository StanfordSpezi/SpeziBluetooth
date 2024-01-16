//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


public enum PeripheralState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
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
