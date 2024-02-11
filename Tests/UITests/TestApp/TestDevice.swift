//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import BluetoothServices
import Foundation
import SpeziBluetooth


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

    @Service var deviceInformation = DeviceInformationService()
    @Service var testService = TestService()

    required init() {}


    func connect() async {
        await self.connect()
    }

    func disconnect() async {
        await self.disconnect()
    }
}


extension BluetoothPeripheral: SomePeripheral {}
