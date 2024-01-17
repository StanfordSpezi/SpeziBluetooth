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
    private let autoConnect: Bool


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

    init(manager: BluetoothManager, autoConnect: Bool) {
        self.manager = manager
        self.autoConnect = autoConnect
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
                    // TODO: this doesn't seem to work sometimes?
                    manager.scanNearbyDevices(autoConnect: autoConnect)
                } else {
                    manager.stopScanning()
                }
            }
    }


    private func onForeground() {
        if bluetoothPoweredOn {
            manager.scanNearbyDevices(autoConnect: autoConnect)
        }
    }

    private func onBackground() {
        manager.stopScanning()
    }
}


extension View {
    // TODO: can this be a protocol?

    /// Scan for nearby bluetooth devices.
    ///
    /// Scans on nearby devices based on the ``DiscoveryConfiguration`` provided in the ``BluetoothManager/init(discovery:minimumRSSI:advertisementStaleTimeout:)``.
    /// All discovered devices can be accessed through the ``BluetoothManager/nearbyPeripherals`` property.
    ///
    /// Nearby device search is automatically paused when the view disappears or if the app enters background and
    /// is automatically started again when the view appears or the app enters the foreground again.
    /// Further, scanning is automatically started if Bluetooth is turned on by the user while the view was already presented.
    ///
    /// - Parameters:
    ///   - manager: The Bluetooth Manager to use for scanning.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to the nearby device if only one is found.
    /// - Returns: The modified view.
    public func scanNearbyDevices(with manager: BluetoothManager, autoConnect: Bool = false) -> some View {
        modifier(BluetoothScanModifier(manager: manager, autoConnect: autoConnect))
    }
}
