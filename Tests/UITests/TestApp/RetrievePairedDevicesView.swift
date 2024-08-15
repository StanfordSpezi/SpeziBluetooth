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


struct RetrievePairedDevicesView: View {
    @Environment(Bluetooth.self)
    private var bluetooth

    @Binding private var pairedDeviceId: UUID?
    @Binding private var retrievedDevice: TestDevice?

    @State private var viewState: ViewState = .idle

    var body: some View {
        Group {
            if let pairedDeviceId {
                List {
                    Section {
                        ListRow("Device") {
                            Text("Paired")
                        }
                        if let retrievedDevice {
                            ListRow("State") {
                                Text(retrievedDevice.state.description)
                            }
                        }

                        deviceButtons(for: pairedDeviceId)
                    }

                    if let retrievedDevice, case .connected = retrievedDevice.state {
                        DeviceInformationView(retrievedDevice)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Device Paired",
                    systemImage: "sensor",
                    description: Text("Select a connected device in the Test Peripheral view to pair.")
                )
            }
        }
            .navigationTitle("Paired Device")
    }


    init(pairedDeviceId: Binding<UUID?>, retrievedDevice: Binding<TestDevice?>) {
        self._pairedDeviceId = pairedDeviceId
        self._retrievedDevice = retrievedDevice
    }


    @ViewBuilder
    @MainActor
    private func deviceButtons(for pairedDeviceId: UUID) -> some View {
        AsyncButton("Unpair Device") {
            await retrievedDevice?.disconnect()
            retrievedDevice = nil
            self.pairedDeviceId = nil
        }
        if let retrievedDevice {
            let state = retrievedDevice.state

            if state == .disconnected || state == .connecting {
                AsyncButton("Connect Device", state: $viewState) {
                    try await retrievedDevice.connect()
                }
            }

            if state == .connecting || state == .connected || state == .disconnecting {
                AsyncButton("Disconnect Device") {
                    await retrievedDevice.disconnect()
                }
            }
        } else {
            AsyncButton("Retrieve Device") {
                let bluetooth = bluetooth
                retrievedDevice = await bluetooth.retrieveDevice(for: pairedDeviceId)
            }
        }
    }
}


#Preview {
    NavigationStack {
        RetrievePairedDevicesView(pairedDeviceId: .constant(nil), retrievedDevice: .constant(nil))
            .previewWith {
                Bluetooth {
                    Discover(TestDevice.self, by: .advertisedService("FFF0"))
                }
            }
    }
}
