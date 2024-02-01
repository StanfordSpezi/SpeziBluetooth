//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth

struct MockBluetoothDevice: GenericBluetoothPeripheral { // TODO: where to put that?
    var label: String
    var state: PeripheralState
    var requiresUserAttention: Bool

    init(label: String, state: PeripheralState, requiresUserAttention: Bool = false) {
        self.label = label
        self.state = state
        self.requiresUserAttention = requiresUserAttention
    }
}


public protocol GenericBluetoothPeripheral {
    var label: String { get }

    var accessibilityLabel: String { get }

    var state: PeripheralState { get }

    var requiresUserAttention: Bool { get }
}


extension GenericBluetoothPeripheral {
    public var accessibilityLabel: String {
        label
    }

    public var requiresUserAttention: Bool {
        false
    }
}
