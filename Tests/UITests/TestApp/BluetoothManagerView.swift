//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI

struct BluetoothManagerView: View {
    @State private var bluetooth = BluetoothManager(discoverBy: [])

    var body: some View {
        Text("Is Scanning: \(bluetooth.isScanning ? "YES": "NO")")
        Text("Bluetooth State: \(bluetooth.state.rawValue)")
            .scanNearbyDevices(with: bluetooth)

        // TODO scan modifier!!!!
    }
}

#Preview {
    BluetoothManagerView()
}
