//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI


struct BluetoothManagerView: View { // TODO: make this a reusable view (with debug output configuration?)
    @State private var bluetooth = BluetoothManager(discoverBy: [])

    var body: some View {
        List {
            Section("State Tests") {
                HStack {
                    Text("Scanning")
                    Spacer()
                    Text(bluetooth.isScanning ? "Yes": "No")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("State")
                    Spacer()
                    Text(bluetooth.state.rawValue)
                        .foregroundColor(.secondary)
                }
            }

            if bluetooth.nearbyPeripheralsView.isEmpty {
                VStack {
                    Text("Searching for nearby devices ...")
                        .foregroundColor(.secondary)
                    ProgressView()
                }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(bluetooth.nearbyPeripheralsView) { device in
                        DeviceRowView(peripheral: device)
                    }
                } header: {
                    HStack {
                        Text("Devices")
                            .padding(.trailing, 10)
                        if bluetooth.isScanning {
                            ProgressView()
                        }
                    }
                }
            }
        }
                .scanNearbyDevices(with: bluetooth)
                .navigationTitle("Nearby Devices")
    }
}

#Preview {
    BluetoothManagerView()
}
