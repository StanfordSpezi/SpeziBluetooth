//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices
import SpeziBluetooth


class HealthThermometerDevice: BluetoothDevice {
    @Service(id: .deviceInformationService)
    var deviceInformation = DeviceInformationService()
    @Service(id: .healthThermometerService)
    var healthThermometer = HealthThermometerService()

    
    required init() {}
}
