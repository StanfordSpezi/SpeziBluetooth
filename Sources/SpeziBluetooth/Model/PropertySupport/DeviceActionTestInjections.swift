//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class DeviceActionTestInjections<ClosureType: Sendable>: Sendable {
    private nonisolated(unsafe) var _injectedClosure: ClosureType?
    private let lock = NSLock() // protects property above

    var injectedClosure: ClosureType? {
        get {
            lock.withLock {
                _injectedClosure
            }
        }
        set {
            lock.withLock {
                _injectedClosure = newValue
            }
        }
    }

    init() {}
}
