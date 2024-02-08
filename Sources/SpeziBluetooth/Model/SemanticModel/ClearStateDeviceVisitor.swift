//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


private struct ClearStateServiceVisitor: ServiceVisitor {
    func visit<Value>(_ characteristic: Characteristic<Value>) {
        characteristic.injection?.assumeIsolated { injection in
            injection.clearState()
        }
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        state.injection?.assumeIsolated { injection in
            injection.clearOnChangeClosure()
        }
    }
}


private struct ClearStateDeviceVisitor: DeviceVisitor {
    func visit<S: BluetoothService>(_ service: Service<S>) {
        var visitor = ClearStateServiceVisitor()
        service.wrappedValue.accept(&visitor)
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        state.injection?.assumeIsolated { injection in
            injection.clearOnChangeClosure()
        }
    }
}


extension BluetoothDevice {
    func clearState(peripheral: BluetoothPeripheral) {
        peripheral.bluetoothQueue.assertIsolated("ClearStateDeviceVisitor must be called within the BluetoothSerialExecutor!")
        var visitor = ClearStateDeviceVisitor()
        accept(&visitor)
    }
}
