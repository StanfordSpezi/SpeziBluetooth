//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI


private struct BluetoothScanModifier: ViewModifier {
    private let manager: BluetoothManager


    init(manager: BluetoothManager) {
        self.manager = manager
    }

    private var bluetoothPoweredOn: Bool {
        if case .poweredOn = manager.state {
            return true
        }
        // TODO: behavior???
#if targetEnvironment(simulator)
        return true
#else
        return ProcessInfo.processInfo.isPreviewSimulator
#endif
    }


    func body(content: Content) -> some View {
        content
            .onAppear(perform: onForeground)
            .onDisappear(perform: onBackground)
            .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) { _ in
                onForeground() // onAppear is coupled with view rendering only and won't get fired when putting app into the foreground
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)) { _ in
                onBackground() // onDisappear is coupled with view rendering only and won't get fired when putting app into the background
            }
            .onChange(of: manager.state) {
                if case .poweredOn = manager.state {
                    // TODO: this doesn't seem to work??
                    manager.scanNearbyDevices() // TODO: pass on auto-connect flag!
                } else {
                    // TODO: check API MISUSE???
                    print("Stopping Scan!")
                    manager.stopScanning()
                }
            }
    }


    private func onForeground() {
        if bluetoothPoweredOn {
            print("SCANNING?")
            manager.scanNearbyDevices()
        }
    }

    private func onBackground() {
        manager.stopScanning() // TODO: should there be a check for API misuse if we are powered off?
    }
}


extension View {
    // TODO: can this be a protocol?
    // TODO: auto-connect flag => find first and then connect if unique (for a certain back off period)?
    public func scanNearbyDevices(with manager: BluetoothManager) -> some View {
        modifier(BluetoothScanModifier(manager: manager))
    }
}
