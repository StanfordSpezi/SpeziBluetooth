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
    // TODO: @State private var bluetooth = BluetoothManager(discovery: []) // discovery any devices!
    @Environment(Bluetooth.self)
    private var bluetooth
    @Environment(TestDevice.self)
    private var device: TestDevice?

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

            let nearbyDevices = bluetooth.nearbyDevices(for: TestDevice.self)

            if nearbyDevices.isEmpty {
                VStack {
                    Text("Searching for nearby devices ...")
                        .foregroundColor(.secondary)
                    ProgressView()
                }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(nearbyDevices) { device in
                        Text("\(String(describing: device))")
                        // TODO: DeviceRowView(peripheral: device)
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
            
            if let device {
                Section {
                    Text("Device State: \(device.state.rawValue)")
                    Text("RSSI: \(device.rssi)")
                }
            }
        }
                .scanNearbyDevices(with: bluetooth, autoConnect: true)
                .navigationTitle("Nearby Devices")
    }
}

#Preview {
    BluetoothManagerView()
        .previewWith {
            Bluetooth {
                Discover(TestDevice.self, by: .primaryService("0000FFF0-0000-1000-8000-00805F9B34FB"))
            }
        }
}
