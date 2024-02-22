//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


class SurroundingScanModifiers: EnvironmentKey {
    static let defaultValue = SurroundingScanModifiers()

    @MainActor private var registeredModifiers: [AnyHashable: Set<UUID>] = [:]

    @MainActor
    func setModifierScanningState<Scanner: BluetoothScanner>(enabled: Bool, with scanner: Scanner, modifierId: UUID) {
        if enabled {
            registeredModifiers[AnyHashable(scanner.id), default: []]
                .insert(modifierId)
        } else {
            registeredModifiers[AnyHashable(scanner.id), default: []]
                .remove(modifierId)
        }
    }

    @MainActor
    func hasPersistentInterest<Scanner: BluetoothScanner>(for scanner: Scanner) -> Bool {
        guard let ids = registeredModifiers[AnyHashable(scanner.id)] else {
            return false
        }
        return !ids.isEmpty
    }
}


extension EnvironmentValues {
    var surroundingScanModifiers: SurroundingScanModifiers {
        get {
            self[SurroundingScanModifiers.self]
        }
        set {
            self[SurroundingScanModifiers.self] = newValue
        }
    }
}
