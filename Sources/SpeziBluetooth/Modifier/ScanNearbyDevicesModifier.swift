//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI


private struct ScanModifierStates: EnvironmentKey {
    static let defaultValue = ScanModifierStates()

    private var registeredModifiers: [AnyHashable: Bool] = [:]

    func parentScanning<Scanner: BluetoothScanner>(with scanner: Scanner) -> Bool {
        registeredModifiers[AnyHashable(scanner.id), default: false]
    }

    func appending<Scanner: BluetoothScanner>(_ scanner: Scanner, enabled: Bool) -> ScanModifierStates {
        var registeredModifiers = registeredModifiers
        registeredModifiers[AnyHashable(scanner.id)] = enabled
        return ScanModifierStates(registeredModifiers: registeredModifiers)
    }
}

extension EnvironmentValues {
    // TODO: naming and moving!
    fileprivate var scanModifierStates: ScanModifierStates {
        get {
            self[ScanModifierStates.self]
        }
        set {
            self[ScanModifierStates.self] = newValue
        }
    }
}


private struct ScanNearbyDevicesModifier<Scanner: BluetoothScanner>: ViewModifier {
    private let enabled: Bool
    private let scanner: Scanner
    private let autoConnect: Bool

    @Environment(\.scanModifierStates)
    private var modifierStates

    init(enabled: Bool, scanner: Scanner, autoConnect: Bool) {
        self.enabled = enabled
        self.scanner = scanner
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
            .onChange(of: enabled, initial: false) {
                if enabled {
                    onForeground()
                } else {
                    onBackground()
                }
            }
            .onChange(of: autoConnect, initial: false) {
                Task {
                    await scanner.setAutoConnect(autoConnect)
                }
            }
            .environment(\.scanModifierStates, modifierStates.appending(scanner, enabled: enabled))
    }

    @MainActor
    private func onForeground() {
        if enabled {
            Task {
                await scanner.scanNearbyDevices(autoConnect: autoConnect)
            }
        }
    }

    @MainActor
    private func onBackground() {
        if modifierStates.parentScanning(with: scanner) {
            return // don't stop scanning if a parent modifier is expecting a scan to continue
        }

        Task {
            await scanner.stopScanning()
        }
    }
}


extension View {
    /// Scan for nearby Bluetooth devices.
    ///
    /// Nearby device search is automatically paused when the view disappears or if the app enters background and
    /// is automatically started again when the view appears or the app enters the foreground again.
    /// Further, scanning is automatically started if Bluetooth is turned on by the user while the view was already presented.
    ///
    /// The auto connect feature allows you to automatically connect to a bluetooth peripheral if it is the only device
    /// discovered for a short period in time.
    ///
    /// - Tip: If you want to continuously search for auto-connectable device in the background,
    ///     you might want to use the ``SwiftUI/View/autoConnect(enabled:with:)`` modifier instead.
    ///
    /// How nearby devices are accessed depends on the passed ``BluetoothScanner`` implementation.
    ///
    /// - Parameters:
    ///   - enabled: Flag indicating if nearby device scanning is enabled.
    ///   - scanner: The Bluetooth Manager to use for scanning.
    ///   - autoConnect: If enabled, the bluetooth manager will automatically connect to the nearby device if only one is found.
    /// - Returns: The modified view.
    ///
    /// ## Topics
    ///
    /// ### Bluetooth Scanner
    /// - ``BluetoothScanner``
    public func scanNearbyDevices<Scanner: BluetoothScanner>(enabled: Bool = true, with scanner: Scanner, autoConnect: Bool = false) -> some View {
        // swiftlint:disable:previous function_default_parameter_at_end
        modifier(ScanNearbyDevicesModifier(enabled: enabled, scanner: scanner, autoConnect: autoConnect))
    }
}
