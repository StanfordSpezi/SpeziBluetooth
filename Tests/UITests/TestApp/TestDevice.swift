//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices
import Foundation
import SpeziBluetooth


protocol SomePeripheral {
    var id: UUID { get }
    var name: String? { get }
    var state: PeripheralState { get }
    var rssi: Int { get }

    func connect() async
    func disconnect() async
}


class TestDevice: BluetoothDevice, Identifiable, SomePeripheral {
    @DeviceState(\.id)
    var id
    @DeviceState(\.name)
    var name
    @DeviceState(\.state)
    var state
    @DeviceState(\.rssi)
    var rssi

    @DeviceAction(\.connect)
    var connect
    @DeviceAction(\.disconnect)
    var disconnect

    @Service
    var deviceInformation = DeviceInformationService()

    required init() {}


    func connect() async {
        await self.connect()
    }

    func disconnect() async {
        await self.disconnect()
    }
}


extension BluetoothPeripheral: SomePeripheral {}
