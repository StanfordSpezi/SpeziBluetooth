//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


private struct SetupServiceVisitor: ServiceVisitor {
    private let bluetooth: Bluetooth
    private let peripheral: BluetoothPeripheral
    private let serviceId: CBUUID
    private let service: GATTService?
    private let didInjectAnything: Box<Bool>


    init(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, serviceId: CBUUID, service: GATTService?, didInjectAnything: Box<Bool>) {
        self.bluetooth = bluetooth
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.service = service
        self.didInjectAnything = didInjectAnything
    }

    func visit<Value>(_ characteristic: Characteristic<Value>) {
        characteristic.inject(bluetooth: bluetooth, peripheral: peripheral, serviceId: serviceId, service: service)
        didInjectAnything.value = true
    }

    func visit<Action: _BluetoothPeripheralAction>(_ action: DeviceAction<Action>) {
        action.inject(bluetooth: bluetooth, peripheral: peripheral)
        didInjectAnything.value = true
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        state.inject(bluetooth: bluetooth, peripheral: peripheral)
        didInjectAnything.value = true
    }
}


private struct SetupDeviceVisitor: DeviceVisitor {
    private let bluetooth: Bluetooth
    private let peripheral: BluetoothPeripheral
    private let didInjectAnything: Box<Bool>


    init(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, didInjectAnything: Box<Bool>) {
        self.bluetooth = bluetooth
        self.peripheral = peripheral
        self.didInjectAnything = didInjectAnything
    }


    func visit<S: BluetoothService>(_ service: Service<S>) {
        let blService = peripheral.assumeIsolated { $0.getService(id: service.id) }
        service.inject(peripheral: peripheral, service: blService)

        var visitor = SetupServiceVisitor(
            bluetooth: bluetooth,
            peripheral: peripheral,
            serviceId: service.id,
            service: blService,
            didInjectAnything: didInjectAnything
        )
        service.wrappedValue.accept(&visitor)
    }

    func visit<Action: _BluetoothPeripheralAction>(_ action: DeviceAction<Action>) {
        action.inject(bluetooth: bluetooth, peripheral: peripheral)
        didInjectAnything.value = true
    }

    func visit<Value>(_ state: DeviceState<Value>) {
        state.inject(bluetooth: bluetooth, peripheral: peripheral)
        didInjectAnything.value = true
    }
}


extension BluetoothDevice {
    func inject(peripheral: BluetoothPeripheral, using bluetooth: Bluetooth) -> Bool {
        peripheral.bluetoothQueue.assertIsolated("SetupDeviceVisitor must be called within the Bluetooth SerialExecutor!")

        // if we don't inject anything, we do not need to retain the device
        let didInjectAnything = Box(false)

        var visitor = SetupDeviceVisitor(bluetooth: bluetooth, peripheral: peripheral, didInjectAnything: didInjectAnything)
        accept(&visitor)

        return didInjectAnything.value
    }
}
