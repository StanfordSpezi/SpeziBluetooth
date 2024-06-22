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
