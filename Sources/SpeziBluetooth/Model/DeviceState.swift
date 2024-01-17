//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


@propertyWrapper
public class DeviceState<Value> { // TODO: can appear anywhere right?
    private let keyPath: KeyPath<BluetoothPeripheral, Value>

    public var wrappedValue: Value {
        guard let peripheral else {
            // TODO: this is always present right
            preconditionFailure("Injection should be present right??")
        }
        return peripheral[keyPath: keyPath]
    }

    private var peripheral: BluetoothPeripheral?


    public init(_ keyPath: KeyPath<BluetoothPeripheral, Value>) {
        self.keyPath = keyPath
    }


    func inject(peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
    }
}


extension DeviceState: DeviceVisitable, ServiceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }

    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
