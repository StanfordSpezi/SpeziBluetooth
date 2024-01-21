//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI


private struct ScanNearbyDevicesModifier<Scanner: BluetoothScanner>: ViewModifier {
    private let scanner: Scanner
    private let autoConnect: Bool


    init(manager: Scanner, autoConnect: Bool) {
        self.scanner = manager
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
            .onChange(of: scanner.state) { // TODO: does this actually trigger a view rerender?
                if case .poweredOn = scanner.state {
                    // TODO: this doesn't seem to work sometimes?
                    scanner.scanNearbyDevices(autoConnect: autoConnect)
                } else {
                    scanner.stopScanning()
                }
            }
    }


    private func onForeground() {
        if case .poweredOn = scanner.state {
            scanner.scanNearbyDevices(autoConnect: autoConnect)
        }
    }

    private func onBackground() {
        scanner.stopScanning()
    }
}


extension View {
    /// Scan for nearby bluetooth devices.
    ///
    /// How nearby devices are accessed depends on the passed ``BluetoothScanner`` implementation.
    ///
    /// Nearby device search is automatically paused when the view disappears or if the app enters background and
    /// is automatically started again when the view appears or the app enters the foreground again.
    /// Further, scanning is automatically started if Bluetooth is turned on by the user while the view was already presented.
    ///
    /// The auto connect feature allows you to automatically connect to a bluetooth peripheral if it is the only device
    /// discovered for a short period in time. // TODO: link to auto connect modifier?
    ///
    /// - Parameters:
    ///   - manager: The Bluetooth Manager to use for scanning.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to the nearby device if only one is found.
    /// - Returns: The modified view.
    ///
    /// ## Topics
    ///
    /// ### Bluetooth Scanner
    /// - ``BluetoothScanner``
    public func scanNearbyDevices<Scanner: BluetoothScanner>(with manager: Scanner, autoConnect: Bool = false) -> some View {
        // TODO: configure case, stop scanning after auto connect (but start again if device disconnects) => autoConnect modifier!
        modifier(ScanNearbyDevicesModifier(manager: manager, autoConnect: autoConnect)) // TODO: enabled bool input!
    }
}
