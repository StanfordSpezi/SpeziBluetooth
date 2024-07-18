//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


@SpeziBluetooth
final class ControlPointTransaction<Value: Sendable>: Sendable {
    let id: UUID

    private(set) var continuation: CheckedContinuation<Value, Error>?

    init(id: UUID = UUID()) {
        self.id = id
    }

    func assignContinuation(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func signalCancellation() {
        resume(with: .failure(CancellationError()))
    }

    func signalTimeout() {
        resume(with: .failure(TimeoutError()))
    }

    func fulfill(_ value: Value) {
        resume(with: .success(value))
    }

    private func resume(with result: Result<Value, Error>) {
        guard let continuation else {
            return
        }

        continuation.resume(with: result)
        self.continuation = nil
    }
}
