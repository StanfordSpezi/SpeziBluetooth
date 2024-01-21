//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziBluetooth
import SwiftUI

class TestDevice: BluetoothDevice, Identifiable {
    @DeviceState(\.state)
    var state

    @DeviceState(\.rssi)
    var rssi

    required init() {}
}


class TestAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                Discover(TestDevice.self, by: .advertisedService("0000FFF0-0000-1000-8000-00805F9B34FB"))
            }
        }
    }
}
