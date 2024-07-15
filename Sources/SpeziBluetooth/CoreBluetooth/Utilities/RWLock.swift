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
        let status = pthread_rwlock_rdlock(&rwLock)
        assert(status == 0, "pthread_rwlock_rdlock failed with status \(status)")
        defer {
            let status = pthread_rwlock_unlock(&rwLock)
            assert(status == 0, "pthread_rwlock_unlock failed with status \(status)")
        }
        return try body()
    }

    /// Call `body` with a writing lock.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    func withWriteLock<T>(body: () throws -> T) rethrows -> T {
        let status = pthread_rwlock_wrlock(&rwLock)
        assert(status == 0, "pthread_rwlock_wrlock failed with status \(status)")
        defer {
            let status = pthread_rwlock_unlock(&rwLock)
            assert(status == 0, "pthread_rwlock_unlock failed with status \(status)")
        }
        return try body()
    }

    func isWriteLocked() -> Bool {
        let status = pthread_rwlock_trywrlock(&rwLock)

        // see status description https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/pthread_rwlock_trywrlock.3.html
        switch status {
        case 0:
            pthread_rwlock_unlock(&rwLock)
            return false
        case EBUSY: // The calling thread is not able to acquire the lock without blocking.
            return false // means we aren't locked
        case EDEADLK: // The calling thread already owns the read/write lock (for reading or writing).
            return true
        default:
            preconditionFailure("Unexpected status from pthread_rwlock_tryrdlock: \(status)")
        }
    }

    deinit {
        let status = pthread_rwlock_destroy(&rwLock)
        assert(status == 0)
    }
}
