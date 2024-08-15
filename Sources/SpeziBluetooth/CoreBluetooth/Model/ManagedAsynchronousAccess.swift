//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation


@SpeziBluetooth
final class ManagedAsynchronousAccess<Value, E: Error> {
    private let access: AsyncSemaphore
    private var continuation: CheckedContinuation<Value, E>?

    var isRunning: Bool {
        continuation != nil
    }

    init(_ value: Int = 1) {
        self.access = AsyncSemaphore(value: value)
    }

    func resume(with result: sending Result<Value, E>) {
        if let continuation {
            self.continuation = nil
            access.signal()
            continuation.resume(with: result)
        }
    }

    func resume(throwing error: E) {
        resume(with: .failure(error))
    }

    func resume(returning value: sending Value) {
        resume(with: .success(value))
    }
}


extension ManagedAsynchronousAccess where Value == Void {
    func resume() {
        self.resume(returning: ())
    }
}


extension ManagedAsynchronousAccess where E == Error {
    func perform(action: () -> Void) async throws -> Value {
        try await access.waitCheckingCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            assert(self.continuation == nil, "continuation was unexpectedly not nil")
            self.continuation = continuation
            action()
        }
    }

    func cancelAll(error: E? = nil) {
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: error ?? CancellationError())
        }
        access.cancelAll()
    }
}


extension ManagedAsynchronousAccess where Value == Void, E == Never {
    func perform(action: () -> Void) async throws {
        try await access.waitCheckingCancellation()

        await withCheckedContinuation { continuation in
            assert(self.continuation == nil, "continuation was unexpectedly not nil")
            self.continuation = continuation
            action()
        }
    }

    func cancelAll() {
        if let continuation {
            self.continuation = nil
            continuation.resume()
        }
        access.cancelAll()
    }
}
