//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


@SpeziBluetooth
private struct SetupServiceVisitor: ServiceVisitor {
    private let bluetooth: Bluetooth
    private let peripheral: BluetoothPeripheral
    private let serviceId: BTUUID
    private let service: GATTService?
    private let didInjectAnything: Box<Bool>


    init(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, serviceId: BTUUID, service: GATTService?, didInjectAnything: Box<Bool>) {
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


@SpeziBluetooth
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
        let blService = peripheral.getService(id: service.id)
        service.inject(bluetooth: bluetooth, peripheral: peripheral, service: blService)
        didInjectAnything.value = true

        var visitor = SetupServiceVisitor(
            bluetooth: bluetooth,
            peripheral: peripheral,
            serviceId: service.id,
            service: blService,
            didInjectAnything: didInjectAnything
        )
        service.wrappedValue.accept(&visitor)

        // call configure once the service is fully set up
        service.wrappedValue.configure()
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
    @SpeziBluetooth
    func inject(peripheral: BluetoothPeripheral, using bluetooth: Bluetooth) -> Bool {
        // if we don't inject anything, we do not need to retain the device
        let didInjectAnything = Box(false)

        var visitor = SetupDeviceVisitor(bluetooth: bluetooth, peripheral: peripheral, didInjectAnything: didInjectAnything)
        accept(&visitor)

        return didInjectAnything.value
    }
}
