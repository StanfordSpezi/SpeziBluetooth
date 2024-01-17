//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


private struct SetupServiceVisitor: ServiceVisitor {
    private let peripheral: BluetoothPeripheral
    private let serviceId: CBUUID
    private let service: CBService?


    init(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: CBService?) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.service = service
    }


    func visit<Value>(_ characteristic: Characteristic<Value>) {
        characteristic.inject(peripheral: peripheral, serviceId: serviceId, service: service)
    }

    func visit<Action: _BluetoothPeripheralAction>(_ action: DeviceAction<Action>) {
        action.inject(peripheral: peripheral)
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        state.inject(peripheral: peripheral)
    }
}


private struct SetupDeviceVisitor: DeviceVisitor {
    private let peripheral: BluetoothPeripheral


    init(peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
    }


    func visit<S: BluetoothService>(_ service: Service<S>) {
        let cbService = peripheral.services?.first(where: { $0.uuid == service.id })

        var visitor = SetupServiceVisitor(peripheral: peripheral, serviceId: service.id, service: cbService)
        service.wrappedValue.accept(&visitor)
    }

    func visit<Action: _BluetoothPeripheralAction>(_ action: DeviceAction<Action>) {
        action.inject(peripheral: peripheral)
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        state.inject(peripheral: peripheral)
    }
}


extension BluetoothDevice {
    func inject(peripheral: BluetoothPeripheral) {
        var visitor = SetupDeviceVisitor(peripheral: peripheral)
        accept(&visitor)
    }
}
