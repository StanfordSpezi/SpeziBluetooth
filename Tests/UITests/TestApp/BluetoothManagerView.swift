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
    @State private var bluetooth = BluetoothManager(devices: []) // discovery any devices!

    var body: some View {
        List {
            Section("State") { // TODO: can we reuse this section somehow?
                HStack {
                    Text("Scanning")
                    Spacer()
                    Text(bluetooth.isScanning ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Text("State")
                    Spacer()
                    Text(bluetooth.state.description)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if bluetooth.nearbyPeripheralsView.isEmpty {
                SearchingNearbyDevicesView()
            } else {
                Section {
                    ForEach(bluetooth.nearbyPeripheralsView) { peripheral in
                        DeviceRowView(peripheral: peripheral)
                    }
                } header: {
                    DevicesHeader(loading: bluetooth.isScanning)
                }
            }
        }
                .scanNearbyDevices(with: bluetooth)
                .navigationTitle("Nearby Devices")
    }
}


#Preview {
    NavigationStack {
        BluetoothManagerView()
    }
}
