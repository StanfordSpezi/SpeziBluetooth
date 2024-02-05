//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class AsyncSemaphore {
    private enum Suspension {
        case cancelable(UnsafeContinuation<Void, Error>)
        case regular(UnsafeContinuation<Void, Never>)

        func resume() {
            switch self {
            case let .regular(continuation):
                continuation.resume()
            case let .cancelable(continuation):
                continuation.resume()
            }
        }
    }

    private var value: Int
    private var suspendedTasks: [Suspension] = []
    private let nsLock = NSLock()

    init(value: Int = 1) {
        precondition(value >= 0)
        self.value = value
    }

    func lock() {
        nsLock.lock()
    }

    func unlock() {
        nsLock.unlock()
    }

    func wait() async {
        lock()

        value -= 1
        if value >= 0 {
            unlock()
            return
        }

        await withUnsafeContinuation { continuation in
            suspendedTasks.append(.regular(continuation))
            unlock()
        }
    }

    func waitCheckingCancellation() async throws {
        try Task.checkCancellation() // check if we are already cancelled

        lock()

        do {
            // check if we got cancelled while acquiring the lock
            try Task.checkCancellation()
        } catch {
            unlock()
            throw error
        }

        value -= 1 // decrease the value
        if value >= 0 {
            unlock()
            return
        }


        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            if Task.isCancelled {
                value += 1 // restore the value
                unlock()

                continuation.resume(throwing: CancellationError())
            } else {
                suspendedTasks.append(.cancelable(continuation))
                unlock()
            }
        }
    }


    func signal() -> Bool {
        lock()

        value += 1

        guard let first = suspendedTasks.first else {
            unlock()
            return false
        }

        suspendedTasks.removeFirst()
        unlock()

        first.resume()
        return true
    }

    func signalAll() { // TODO: not used!
        lock()

        value += suspendedTasks.count

        let tasks = suspendedTasks
        self.suspendedTasks.removeAll()

        unlock()

        for task in tasks {
            task.resume()
        }
    }

    func cancelAll() {
        lock()

        value += suspendedTasks.count

        let tasks = suspendedTasks
        self.suspendedTasks.removeAll()

        unlock()

        for task in tasks {
            switch task {
            case .regular:
                preconditionFailure("Tried to cancel a task that was not cancellable!")
            case let .cancelable(continuation):
                continuation.resume(throwing: CancellationError())
            }
        }
    }
}
