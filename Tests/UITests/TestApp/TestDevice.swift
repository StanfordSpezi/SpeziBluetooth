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


final class TestDevice: BluetoothDevice, Identifiable, SomePeripheral, @unchecked Sendable {
    @Observable
    class State {
        @MainActor fileprivate(set) var didReceiveManufacturer = false
        @MainActor fileprivate(set) var didReceiveModel = false

        init() {}
    }

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


    let testState = State()

    required init() {
        deviceInformation.$modelNumber.onChange(initial: true) { @MainActor _ in
            self.testState.didReceiveModel = true
        }
        deviceInformation.$manufacturerName.onChange { @MainActor _ in
            self.testState.didReceiveManufacturer = true // this should never be called
        }
    }


    func connect() async {
        await self.connect()
    }

    func disconnect() async {
        await self.disconnect()
    }
}


extension BluetoothPeripheral: SomePeripheral {}
