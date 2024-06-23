//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI


struct BluetoothModuleView: View {
    @Environment(Bluetooth.self)
    private var bluetooth
    @Environment(TestDevice.self)
    private var device: TestDevice?
    @Environment(ConnectedDevices<TestDevice>.self)
    private var connectedDevices

    var body: some View {
        List {
            BluetoothStateSection(state: bluetooth.state, isScanning: bluetooth.isScanning)

            let nearbyDevices = bluetooth.nearbyDevices(for: TestDevice.self)

            Section {
                ForEach(nearbyDevices) { device in
                    DeviceRowView(peripheral: device)
                }
            } header: {
                Text(verbatim: "Devices")
            } footer: {
                Text(verbatim: "This is a list of nearby test peripherals. Auto connect is enabled.")
            }

            if !connectedDevices.isEmpty {
                Section {
                    ForEach(connectedDevices) { device in
                        Text("Connected \(device.name ?? "unknown")")
                    }
                } header: {
                    Text("Connected Devices")
                } footer: {
                    Text("This tests the retrieval of connected devices using ConnectedDevices.")
                }
            }

            if let device {
                NavigationLink("Test Interactions") {
                    TestDeviceView(device: device)
                }
            }
        }
            .scanNearbyDevices(with: bluetooth, autoConnect: true)
            .navigationTitle("Nearby Devices")
    }
}


#Preview {
    NavigationStack {
        BluetoothModuleView()
            .previewWith {
                Bluetooth {
                    Discover(TestDevice.self, by: .advertisedService("FFF0"))
                }
            }
    }
}
