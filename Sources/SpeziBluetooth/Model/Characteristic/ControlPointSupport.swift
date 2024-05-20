//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class ControlPointTransaction<Value>: @unchecked Sendable {
    let id: UUID

    private(set) var continuation: CheckedContinuation<Value, Error>?
    private let lock = NSLock()

    init(id: UUID = UUID()) {
        self.id = id
    }

    func assignContinuation(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()

        defer {
            lock.unlock()
        }

        self.continuation = continuation
    }

    func signalCancellation() {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let continuation else {
            return
        }

        continuation.resume(throwing: CancellationError())
        self.continuation = nil
    }

    func fulfill(_ value: Value) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let continuation else {
            return
        }

        continuation.resume(returning: value)
        self.continuation = nil
    }
}
