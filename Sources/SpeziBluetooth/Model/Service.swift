//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Observation

// TODO: DeviceInjectable protocol?


// TODO rename:
public protocol BluetoothServiceNew: AnyObject { // TODO GATTService name?
    // TODO enum type for Characteristic Ids? (and for service?)
}


@Observable
@propertyWrapper
public class Service<S: BluetoothServiceNew> {
    private let id: CBUUID

    public let wrappedValue: S

    // TODO: do we need a projected value?
    public convenience init(wrappedValue: S, id: String) {
        self.init(wrappedValue: wrappedValue, id: CBUUID(string: id))
    }

    public init(wrappedValue: S, id: CBUUID) {
        self.wrappedValue = wrappedValue
        self.id = id
    }
}
