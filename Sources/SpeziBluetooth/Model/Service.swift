//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


@propertyWrapper
public class Service<S: BluetoothService> {
    let id: CBUUID

    public let wrappedValue: S

    // TODO: underlying access to isPrimary via projectedValue?

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
