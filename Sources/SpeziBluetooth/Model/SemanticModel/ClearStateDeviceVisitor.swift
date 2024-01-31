//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


private struct ClearStateServiceVisitor: ServiceVisitor {
    @MainActor
    func visit<Value>(_ characteristic: Characteristic<Value>) {
        characteristic.clearState()
    }

    @MainActor
    func visit<Value>(_ state: DeviceState<Value>) {
        state.clearState()
    }
}


private struct ClearStateDeviceVisitor: DeviceVisitor {
    func visit<S: BluetoothService>(_ service: Service<S>) {
        var visitor = ClearStateServiceVisitor()
        service.wrappedValue.accept(&visitor)
    }

    @MainActor
    func visit<Value>(_ state: DeviceState<Value>) {
        state.clearState()
    }
}


extension BluetoothDevice {
    func clearState() {
        var visitor = ClearStateDeviceVisitor()
        accept(&visitor)
    }
}
