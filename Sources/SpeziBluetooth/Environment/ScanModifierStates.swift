//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct ScanModifierStates: EnvironmentKey {
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
    var scanModifierStates: ScanModifierStates {
        get {
            self[ScanModifierStates.self]
        }
        set {
            self[ScanModifierStates.self] = newValue
        }
    }
}