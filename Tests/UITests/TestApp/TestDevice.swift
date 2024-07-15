//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziBluetooth
@_spi(TestingSupport)
import SpeziBluetoothServices


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
    private(set) var passedRetainCountCheck = false

    required init() {}

    func configure() {
        let count = CFGetRetainCount(self)

        deviceInformation.$modelNumber.onChange(initial: true) { @MainActor [weak self] _ in
            self?.testState.didReceiveModel = true
        }
        deviceInformation.$manufacturerName.onChange { @MainActor [weak self] _ in
            self?.testState.didReceiveManufacturer = true // this should never be called
        }
        $state.onChange { state in // test DeviceState code path as well, even if its just logging!
            print("State is now \(state)")
        }

        let newCount = CFGetRetainCount(self)
        if count == newCount {
            passedRetainCountCheck = true
        } else {
            print("Failed retain count check, was \(count) now is \(newCount)")
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
