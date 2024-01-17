//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation
import Spezi
// TODO: delete this file!

func test() -> Configuration {
    Configuration {
        Bluetooth {
            Discover(Device.self, by: .primaryService("asdf"))
        }
    }
}

class Device: BluetoothDevice {
    // TODO: keep in mind with the DSL API, what if we don't find something that is declared (service, characteristic)?

    @Service(id: "76763833-123123-123123")
    var primary = MyService()

    @DeviceState(\.name)
    var name

    @DeviceAction(\.connect)
    var connect

    // TODO No dot allow @Characteristic definitions here!
    required init() {}
}


class MyService: BluetoothService { // TODO conformance!
    // TODO: do not allow nested Services

    @Characteristic(id: "0000-789876-1238123")
    var model: String?

    @Characteristic(id: "FFFF")
    var rawData: Data?

    func test() async throws {
        /*
        // TODO: withCharacteriticNotification; capturing self?
        registerCharacteriticNotification(id: "asdf") { data in
        }
        registerCharacteristicNotification(for: $model, perform: self.asdf)

        try await $model.write("Hello World")
        $model.subscribe(true)


        // TODO: also needs a service accessor?; or just specify both ids?
        _ = try await withCharacteristicAccessors(id: "asdf", for: Data.self) { accessors in
            try await accessors.read()
        }
         */
    }
}
