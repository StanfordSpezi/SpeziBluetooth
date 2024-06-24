//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SpeziViews
import SwiftUI


struct BluetoothModuleView: View {
    @Environment(Bluetooth.self)
    private var bluetooth
    @Environment(TestDevice.self)
    private var device: TestDevice?
    @Environment(ConnectedDevices<TestDevice>.self)
    private var connectedDevices

    @Binding private var pairedDeviceId: UUID?

    var body: some View {
        List { // swiftlint:disable:this closure_body_length
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
                        AsyncButton {
                            pairedDeviceId = device.id
                            await device.disconnect()
                        } label: {
                            VStack {
                                Text(verbatim: "Pair \(type(of: device))")
                                if let name = device.name {
                                    Text(name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                            .accessibilityLabel("Pair \(type(of: device))")
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


    init(pairedDeviceId: Binding<UUID?>) {
        self._pairedDeviceId = pairedDeviceId
    }
}


#Preview {
    NavigationStack {
        BluetoothModuleView(pairedDeviceId: .constant(nil))
            .previewWith {
                Bluetooth {
                    Discover(TestDevice.self, by: .advertisedService("FFF0"))
                }
            }
    }
}
