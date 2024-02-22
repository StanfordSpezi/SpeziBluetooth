//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth


/// Mock peripheral used for internal previews.
struct MockBluetoothDevice: GenericBluetoothPeripheral {
    var label: String
    var state: PeripheralState
    var requiresUserAttention: Bool

    init(label: String, state: PeripheralState, requiresUserAttention: Bool = false) {
        self.label = label
        self.state = state
        self.requiresUserAttention = requiresUserAttention
    }
}
