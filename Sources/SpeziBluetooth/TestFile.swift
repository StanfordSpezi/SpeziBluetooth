//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation
// TODO: delete this file!

class Device: BluetoothDevice {
    // TODO: bluetooth device accessors?

    // TODO: how to "connect" and "disconnect"?

    @Service(id: "76763833-123123-123123")
    var primary = MyService()

    @DeviceState(\.name) // TODO: there are also actor accesses?
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
