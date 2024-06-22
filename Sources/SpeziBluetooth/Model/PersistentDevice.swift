//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


// TODO: dynamic member lookup?
public class PersistentDevice<Device: BluetoothDevice> {
    private let bluetooth: Bluetooth
    public let device: Device
    private let peripheralId: UUID

    init(_ bluetooth: Bluetooth, _ device: Device, _ id: UUID) {
        self.bluetooth = bluetooth
        self.device = device
        self.peripheralId = id
    }

    deinit {
        let bluetooth = bluetooth
        let device = device
        Task { @SpeziBluetooth in
            await bluetooth.releaseDevice(device, with: peripheralId)
        }
    }
}
