//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Observation


public protocol BluetoothService: AnyObject { // TODO: GATTService name?
    // TODO: enum type for Characteristic Ids? (and for service?)
}


@propertyWrapper
public class Service<S: BluetoothService> {
    let id: CBUUID

    public let wrappedValue: S

    // TODO: do we need a projected value? maybe for underlying access?

    public convenience init(wrappedValue: S, id: String) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id))
    }

    public init(wrappedValue: S, id: CBUUID) {
        self.wrappedValue = wrappedValue
        self.id = id
    }
}


extension Service: DeviceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
