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
        characteristic.clearState()
    }
}


private struct ClearStateDeviceVisitor: DeviceVisitor {
    func visit<S: BluetoothService>(_ service: Service<S>) {
        var visitor = ClearStateServiceVisitor()
        service.wrappedValue.accept(&visitor)
    }
}


extension BluetoothDevice {
    func clearState() {
        var visitor = ClearStateDeviceVisitor()
        accept(&visitor)
    }
}
