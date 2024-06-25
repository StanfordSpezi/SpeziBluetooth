//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


private struct AdvertisementStaleIntervalEnvironmentKey: EnvironmentKey {
    static let defaultValue: TimeInterval? = nil
}


extension EnvironmentValues {
    public var advertisementStaleInterval: TimeInterval? {
        get {
            self[AdvertisementStaleIntervalEnvironmentKey.self]
        }
        set {
            self[AdvertisementStaleIntervalEnvironmentKey.self] = newValue
        }
    }
}
