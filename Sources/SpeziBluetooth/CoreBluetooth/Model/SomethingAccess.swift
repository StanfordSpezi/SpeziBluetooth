//
//  SomethingAccess.swift
//  SpeziBluetooth
//
//  Created by Andreas Bauer on 14.08.24.
//

import SpeziFoundation

// TODO: think about name, update file name


final class SomethingAccess<Value, E: Error> { // TODO: AsynchronousAccess, ManagedAsynchronousAccess
    private let access = AsyncSemaphore() // TODO: init with value forwarding to semaphore!
    private var continuation: CheckedContinuation<Value, E>?

    var isRunning: Bool {
        continuation != nil
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

    func resume(returning value: sending Value) { // TODO: void overload!
        resume(with: .success(value))
    }
}


extension SomethingAccess where Value == Void {
    func resume() {
        self.resume(returning: ())
    }
}


extension SomethingAccess where E == Error {
    func perform( // TODO: use @SpeziBluetooth for now and move to SpeziFoundation once Swift 6 ships?
        isolation: isolated (any Actor)? = #isolation,
        action: () -> Void
    ) async throws -> Value { // TODO: name?
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


extension SomethingAccess where Value == Void, E == Never {
    func perform(
        isolation: isolated (any Actor)? = #isolation,
        action: () -> Void
    ) async throws {
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
