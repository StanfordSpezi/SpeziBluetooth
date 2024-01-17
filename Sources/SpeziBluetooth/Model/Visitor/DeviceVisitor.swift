//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


protocol DeviceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor)
}


protocol DeviceVisitor: BaseVisitor {
    mutating func visit<S: BluetoothService>(_ service: Service<S>)
}


extension BluetoothDevice {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) { // TODO: any final result?
        let mirror = Mirror(reflecting: self)
        for (_, child) in mirror.children {
            if let visitable = child as? DeviceVisitable {
                visitable.accept(&visitor)
            }
            // TODO: maybe some logger to catch illegal @Characteristic stuff?
        }
    }
}
