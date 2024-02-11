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

    @Service var deviceInformation = DeviceInformationService()
    @Service var testService = TestService()

    required init() {
        $state.onChange { state in
            print("Test state is now \(state)")
            // TODO: assert that we are running on the bluetooth actor by default?
        }
        //deviceInformation.$pnpID.onChange { _ in
            // TODO: assert that we are running on the bluetooth actor by default? (this closure here does not make sense!)
        //}

        testService.$eventLog.onChange { event in
            print("Received a raised event \(event)")
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
