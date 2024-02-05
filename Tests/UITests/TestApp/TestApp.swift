//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziBluetooth
import SwiftUI


class CustomDynamicProperty: Observable, DynamicProperty {
    var someProperty: String {
        print("Hello World")
        return "Hello World"
    }

    func update() {
        print("Update called!")
        Task { @MainActor in
            print("Hello Update world")
        }
    }
}


struct DynamicPropertyTests: View {
    // TODO: think about custom DynamicProperty to support thread-safe update()! with thread local shadow copy and withSafeAccess
    @Environment(CustomDynamicProperty.self)
    private var hello

    var body: some View {
        Text(hello.someProperty)
    }
}


@main
struct UITestsApp: App {
    @UIApplicationDelegateAdaptor(TestAppDelegate.self)
    var appDelegate
    

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    DynamicPropertyTests()
                    NavigationLink("Nearby Devices") {
                        BluetoothManagerView()
                    }
                    NavigationLink("Auto Connect Device") {
                        BluetoothModuleView()
                    }
                }
                    .navigationTitle("Spezi Bluetooth")
            }
                .spezi(appDelegate)
                .environment(CustomDynamicProperty())
        }
    }
}
