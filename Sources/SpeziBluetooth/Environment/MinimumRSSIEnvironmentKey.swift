//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


private struct MinimumRSSIEnvironmentKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}


extension EnvironmentValues {
    public var minimumRSSI: Int? {
        get {
            self[MinimumRSSIEnvironmentKey.self]
        }
        set {
            self[MinimumRSSIEnvironmentKey.self] = newValue
        }
    }
}
