//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation

protocol BluetoothActor: Actor {
    nonisolated var bluetoothQueue: DispatchSerialQueue { get }

    func isolated(perform: (isolated Self) -> Void)
}

extension BluetoothActor {
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        UnownedSerialExecutor(complexEquality: bluetoothQueue)
    }

    func isolated(perform: (isolated Self) -> Void) {
        perform(self)
    }
}

extension BluetoothManager {
    func isolated2(perform: (isolated BluetoothManager) -> Void) {
        perform(self) // TODO: remove?
    }
}

extension BluetoothActor { // TODO: remove?
    nonisolated func preconditionIsolatedUnsafe() {
        // Adapted from https://github.com/apple/swift/blob/a1062d06e9f33512b0005d589e3b086a89cfcbd1/stdlib/public/Concurrency/ExecutorAssertions.swift#L101-L117
        guard _isDebugAssertConfiguration() || _isReleaseAssertConfiguration() else {
            return
        }

        self.preconditionIsolated()
        // TODO: dispatchPrecondition(condition: .onQueue(bluetoothQueue))
    }
}
