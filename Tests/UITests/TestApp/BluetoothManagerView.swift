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
    @State private var bluetooth = BluetoothManager()

    var body: some View {
        List {
            BluetoothStateSection(state: bluetooth.state, isScanning: bluetooth.isScanning)

            Section {
                ForEach(bluetooth.nearbyPeripherals) { peripheral in
                    DeviceRowView(peripheral: peripheral)
                }
            } header: {
                Text(verbatim: "Devices")
            } footer: {
                Text(verbatim: "This is a list of nearby Bluetooth peripherals.")
            }
        }
            .scanNearbyDevices(with: bluetooth, discovery: []) // discovery any devices!
            .navigationTitle("Nearby Devices")
    }
}


#Preview {
    NavigationStack {
        BluetoothManagerView()
    }
}
