//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

protocol AnyWeakDeviceReference {
    var anyValue: (any BluetoothDevice)? { get }

    var typeName: String { get }
}


struct WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value? = nil) {
        self.value = value
    }
}


extension WeakReference: AnyWeakDeviceReference where Value: BluetoothDevice {
    var anyValue: (any BluetoothDevice)? {
        value
    }

    var typeName: String {
        "\(Value.self)"
    }
}
