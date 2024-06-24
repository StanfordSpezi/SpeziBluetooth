//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
@_spi(Internal)
import SpeziBluetooth
import SpeziViews
import SwiftUI

struct NearbyDevices: View {
    var body: some View {
        BluetoothManagerView() // we use this indirection to trigger BluetoothManager deinit!
    }
}

struct DeviceCountButton: View {
    @Environment(Bluetooth.self)
    private var bluetooth

    @State private var lastReadCount: Int?

    var body: some View {
        Section {
            AsyncButton("Query Count") {
                lastReadCount = await bluetooth._initializedDevicesCount()
            }
            .onDisappear {
                lastReadCount = nil
            }
        } footer: {
            if let lastReadCount {
                Text("Currently initialized devices: \(lastReadCount)")
            }
        }
    }
}

@main
struct UITestsApp: App {
    @UIApplicationDelegateAdaptor(TestAppDelegate.self)
    var appDelegate

    @State private var pairedDeviceId: UUID?
    @State private var retrievedDevice: TestDevice?


    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("Nearby Devices") {
                        NearbyDevices()
                    }
                    NavigationLink("Test Peripheral") {
                        BluetoothModuleView(pairedDeviceId: $pairedDeviceId)
                    }
                    NavigationLink("Paired Device") {
                        RetrievePairedDevicesView(pairedDeviceId: $pairedDeviceId, retrievedDevice: $retrievedDevice)
                    }

                    DeviceCountButton()
                }
                    .navigationTitle("Spezi Bluetooth")
            }
                .spezi(appDelegate)
        }
    }
}
