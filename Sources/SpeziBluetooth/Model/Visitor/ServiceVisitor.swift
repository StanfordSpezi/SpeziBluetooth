//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


protocol ServiceVisitable {
    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor)
}


protocol ServiceVisitor: BaseVisitor {
    mutating func visit<Value>(_ characteristic: Characteristic<Value>)
}


extension BluetoothService {
    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        let mirror = Mirror(reflecting: self)
        for (_, child) in mirror.children {
            if let visitable = child as? ServiceVisitable {
                visitable.accept(&visitor)
            } else if child is DeviceVisitable {
                preconditionFailure("@Service declaration found in \(Self.self). @Service cannot be used within BluetoothService classes!")
            }
        }
    }
}
