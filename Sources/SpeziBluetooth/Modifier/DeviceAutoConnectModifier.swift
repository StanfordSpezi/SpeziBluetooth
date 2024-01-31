//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


private struct DeviceAutoConnectModifier<Scanner: BluetoothScanner>: ViewModifier {
    private let enabled: Bool
    private let scanner: Scanner

    private var shouldScan: Bool {
        enabled && !scanner.hasConnectedDevices
    }

    init(enabled: Bool, scanner: Scanner) {
        self.enabled = enabled
        self.scanner = scanner
    }

    func body(content: Content) -> some View {
        content
            .scanNearbyDevices(enabled: shouldScan, with: scanner, autoConnect: true)
    }
}


extension View {
    /// Scan for nearby Bluetooth devices and auto connect.
    ///
    /// Scans for nearby Bluetooth devices till a device to auto connect to is discovered.
    /// Device scanning is automatically started again if the device happens to disconnect.
    ///
    /// How nearby devices are accessed depends on the passed ``BluetoothScanner`` implementation.
    ///
    /// - Parameters:
    ///   - enabled: Flag indicating if nearby device scanning is enabled.
    ///   - scanner: The Bluetooth Manager to use for scanning.
    /// - Returns: THe modified view.
    public func autoConnect<Scanner: BluetoothScanner>(enabled: Bool = false, with scanner: Scanner) -> some View { // TODO: timeout??
        // swiftlint:disable:previous function_default_parameter_at_end
        modifier(DeviceAutoConnectModifier(enabled: enabled, scanner: scanner))
    }
}
