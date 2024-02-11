//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI


@main
struct UITestsApp: App {
    @UIApplicationDelegateAdaptor(TestAppDelegate.self)
    var appDelegate
    

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("Nearby Devices") {
                        BluetoothManagerView()
                    }
                    NavigationLink("Test Peripheral") {
                        BluetoothModuleView()
                    }
                }
                    .navigationTitle("Spezi Bluetooth")
            }
                .spezi(appDelegate)
        }
    }
}
