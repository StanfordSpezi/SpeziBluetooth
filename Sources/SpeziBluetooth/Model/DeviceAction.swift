//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

public protocol _BluetoothPeripheralAction { // swiftlint:disable:this type_name
    init(from peripheral: BluetoothPeripheral)
}

public struct BluetoothConnectAction: _BluetoothPeripheralAction {
    private let peripheral: BluetoothPeripheral // TODO: weakness?

    public init(from peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
    }


    public func callAsFunction() async {
        await peripheral.connect()
    }
}

public struct DeviceActions {
    public var connect: BluetoothConnectAction.Type {
        BluetoothConnectAction.self
    }
}


@propertyWrapper
public class DeviceAction<Action: _BluetoothPeripheralAction> {
    public var wrappedValue: Action {
        guard let peripheral else {
            // TODO: this is always present right
            preconditionFailure("Injection should be present right")
        }
        return Action(from: peripheral)
    }

    var peripheral: BluetoothPeripheral?


    public init(_ keyPath: KeyPath<DeviceActions, Action.Type>) {}
}


extension DeviceAction: DeviceVisitable, ServiceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }

    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
