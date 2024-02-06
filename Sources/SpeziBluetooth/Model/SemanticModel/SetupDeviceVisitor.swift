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
    private let service: GATTService?


    init(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: GATTService?) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.service = service
    }

    func visit<Value>(_ characteristic: Characteristic<Value>) {
        // TODO: just call setup within the inject everywhere (where we pass the peripheral?)
        characteristic.inject(peripheral: peripheral, serviceId: serviceId, service: service)
    }

    func visit<Action: _BluetoothPeripheralAction>(_ action: DeviceAction<Action>) {
        action.inject(peripheral: peripheral)
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        let injection = state.inject(peripheral: peripheral)
        injection.assumeIsolated { injection in
            injection.setup()
        }
    }
}


private struct SetupDeviceVisitor: DeviceVisitor {
    private let peripheral: BluetoothPeripheral


    init(peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
    }


    func visit<S: BluetoothService>(_ service: Service<S>) {
        let blService = peripheral.assumeIsolated { $0.getService(id: service.id) }

        let serviceInjection = ServicePeripheralInjection(peripheral: peripheral, serviceId: service.id, service: blService)
        service.inject(serviceInjection)
        serviceInjection.assumeIsolated { injection in
            injection.setup()
        }

        var visitor = SetupServiceVisitor(peripheral: peripheral, serviceId: service.id, service: blService)
        service.wrappedValue.accept(&visitor)
    }

    func visit<Action: _BluetoothPeripheralAction>(_ action: DeviceAction<Action>) {
        action.inject(peripheral: peripheral)
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        let injection = state.inject(peripheral: peripheral)
        injection.assumeIsolated { injection in
            injection.setup()
        }
    }
}


extension BluetoothDevice {
    func inject(peripheral: BluetoothPeripheral) {
        peripheral.bluetoothExecutor.assertIsolated("SetupDeviceVisitor must be called within the BluetoothSerialExecutor!")
        var visitor = SetupDeviceVisitor(peripheral: peripheral)
        accept(&visitor)
    }
}
