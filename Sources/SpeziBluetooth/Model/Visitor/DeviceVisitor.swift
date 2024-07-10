//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


protocol DeviceVisitable {
    @SpeziBluetooth
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor)
}


@SpeziBluetooth
protocol DeviceVisitor: BaseVisitor {
    mutating func visit<S: BluetoothService>(_ service: Service<S>)
}


extension BluetoothDevice {
    @SpeziBluetooth
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        let mirror = Mirror(reflecting: self)
        for (_, child) in mirror.children {
            if let visitable = child as? DeviceVisitable {
                visitable.accept(&visitor)
            } else if child is ServiceVisitable {
                preconditionFailure("@Characteristic declaration found in \(Self.self). @Characteristic cannot be used within the BluetoothDevice class!")
            }
        }
    }
}
