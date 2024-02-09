//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Global, framework-internal actor to schedule work that is exectued serially.
@globalActor
actor SpeziBluetooth {
    static let shared = SpeziBluetooth()
}
