//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


// CustomDebugStringConvertible is already implemented for NSObjects. So we just define a custom property
extension CBPeripheral {
    var debugIdentifier: String {
        if let name {
            "'\(name)' @ \(identifier)"
        } else {
            "\(identifier)"
        }
    }
}


extension BluetoothPeripheral: CustomDebugStringConvertible {
    public nonisolated var debugDescription: String {
        cbPeripheral.debugIdentifier
    }
}
