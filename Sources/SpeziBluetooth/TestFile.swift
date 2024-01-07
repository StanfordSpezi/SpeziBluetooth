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
    @Service(id: "76763833-123123-123123")
    var primary = MyService()
}

class MyService: BluetoothServiceNew { // TODO conformance!
    @Characteristic(id: CBUUID(string: "0000.--1238123"))
    var model: String? // TODO: Data escape?

    func test() async {
        // TODO: withCharacteriticNotification
        registerCharacteriticNotification(id: "asdf") { data in

        }

        $model.subscribe(true)

        registerCharacteristicNotification(for: $model, perform: self.asdf)

        _ = await withCharacteristicAccessors(id: "asdf", for: Data.self) { accessors in
            await accessors.read()
        }
    }
}
