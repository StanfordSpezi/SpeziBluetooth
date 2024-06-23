//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziBluetooth
@_spi(TestingSupport)
import SpeziBluetoothServices
import SwiftUI


class TestAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                Discover(TestDevice.self, by: .advertisedService(TestService.self))
            }
        }
    }
}
