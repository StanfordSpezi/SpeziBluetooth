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

    func isolated(perform: (isolated Self) throws -> Void) rethrows

    func isolated(perform: (isolated Self) async throws -> Void) async rethrows
}

extension BluetoothActor {
    /// Default implementation returning the unknown serial executor of the dispatch queue.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        bluetoothQueue.asUnownedSerialExecutor()
    }

    func isolated(perform: (isolated Self) throws -> Void) rethrows {
        try perform(self)
    }

    func isolated(perform: (isolated Self) async throws -> Void) async rethrows {
        try await perform(self)
    }
}
