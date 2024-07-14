//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import Foundation


/// Read-Write Lock using `pthread_rwlock`.
///
/// Looking at https://www.vadimbulavin.com/benchmarking-locking-apis, using `pthread_rwlock`
/// is favorable over using dispatch queues.
final class RWLock: @unchecked Sendable {
    private var rwLock = pthread_rwlock_t()

    init() {
        let status = pthread_rwlock_init(&rwLock, nil)
        precondition(status == 0, "pthread_rwlock_init failed with status \(status)")
    }

    /// Call `body` with a reading lock.
    ///
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    func withReadLock<T>(body: () throws -> T) rethrows -> T {
        pthread_rwlock_rdlock(&rwLock)
        defer {
            pthread_rwlock_unlock(&rwLock)
        }
        return try body()
    }

    /// Call `body` with a writing lock.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    func withWriteLock<T>(body: () throws -> T) rethrows -> T {
        pthread_rwlock_wrlock(&rwLock)
        defer {
            pthread_rwlock_unlock(&rwLock)
        }
        return try body()
    }

    deinit {
        let status = pthread_rwlock_destroy(&rwLock)
        assert(status == 0)
    }
}
