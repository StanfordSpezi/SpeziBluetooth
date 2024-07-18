//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import Atomics
import Foundation


private protocol PThreadReadWriteLock: AnyObject {
    // We need the unsafe mutable pointer, as otherwise we need to pass the property as inout parameter which isn't thread safe.
    var rwLock: UnsafeMutablePointer<pthread_rwlock_t> { get }
}


final class RecursiveRWLock: PThreadReadWriteLock, @unchecked Sendable {
    fileprivate let rwLock: UnsafeMutablePointer<pthread_rwlock_t>

    private let writerThread = ManagedAtomic<pthread_t?>(nil)
    private var writerCount = 0
    private var readerCount = 0

    init() {
        rwLock = Self.pthreadInit()
    }


    private func writeLock() {
        let selfThread = pthread_self()

        if let writer = writerThread.load(ordering: .relaxed),
           pthread_equal(writer, selfThread) != 0 {
            // we know that the writerThread is us, so access to `writerCount` is synchronized (its us that holds the rwLock).
            writerCount += 1
            assert(writerCount > 1, "Synchronization issue. Writer count is unexpectedly low: \(writerCount)")
            return
        }

        pthreadWriteLock()

        writerThread.store(selfThread, ordering: .relaxed)
        writerCount = 1
    }

    private func writeUnlock() {
        // we assume this is called while holding the write lock, so access to `writerCount` is safe
        if writerCount > 1 {
            writerCount -= 1
            return
        }

        // otherwise it is the last unlock
        writerThread.store(nil, ordering: .relaxed)
        writerCount = 0

        pthreadUnlock()
    }

    private func readLock() {
        let selfThread = pthread_self()

        if let writer = writerThread.load(ordering: .relaxed),
           pthread_equal(writer, selfThread) != 0 {
            // we know that the writerThread is us, so access to `readerCount` is synchronized (its us that holds the rwLock).
            readerCount += 1
            assert(readerCount > 0, "Synchronization issue. Reader count is unexpectedly low: \(readerCount)")
            return
        }

        pthreadReadLock()
    }

    private func readUnlock() {
        // we assume this is called while holding the reader lock, so access to `readerCount` is safe
        if readerCount > 0 {
            // fine to go down to zero (we still hold the lock in write mode)
            readerCount -= 1
            return
        }

        pthreadUnlock()
    }


    func withWriteLock<T>(body: () throws -> T) rethrows -> T {
        writeLock()
        defer {
            writeUnlock()
        }
        return try body()
    }

    func withReadLock<T>(body: () throws -> T) rethrows -> T {
        readLock()
        defer {
            readUnlock()
        }
        return try body()
    }

    deinit {
        pthreadDeinit()
    }
}


/// Read-Write Lock using `pthread_rwlock`.
///
/// Looking at https://www.vadimbulavin.com/benchmarking-locking-apis, using `pthread_rwlock`
/// is favorable over using dispatch queues.
final class RWLock: PThreadReadWriteLock, @unchecked Sendable {
    fileprivate let rwLock: UnsafeMutablePointer<pthread_rwlock_t>

    init() {
        rwLock = Self.pthreadInit()
    }

    /// Call `body` with a reading lock.
    ///
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    func withReadLock<T>(body: () throws -> T) rethrows -> T {
        pthreadWriteLock()
        defer {
            pthreadUnlock()
        }
        return try body()
    }

    /// Call `body` with a writing lock.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    func withWriteLock<T>(body: () throws -> T) rethrows -> T {
        pthreadWriteLock()
        defer {
            pthreadUnlock()
        }
        return try body()
    }

    func isWriteLocked() -> Bool {
        let status = pthread_rwlock_trywrlock(rwLock)

        // see status description https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/pthread_rwlock_trywrlock.3.html
        switch status {
        case 0:
            pthreadUnlock()
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
        pthreadDeinit()
    }
}


extension PThreadReadWriteLock {
    static func pthreadInit() -> UnsafeMutablePointer<pthread_rwlock_t> {
        let lock: UnsafeMutablePointer<pthread_rwlock_t> = .allocate(capacity: 1)
        let status = pthread_rwlock_init(lock, nil)
        precondition(status == 0, "pthread_rwlock_init failed with status \(status)")
        return lock
    }

    func pthreadWriteLock() {
        let status = pthread_rwlock_wrlock(rwLock)
        assert(status == 0, "pthread_rwlock_wrlock failed with status \(status)")
    }

    func pthreadReadLock() {
        let status = pthread_rwlock_rdlock(rwLock)
        assert(status == 0, "pthread_rwlock_rdlock failed with status \(status)")
    }

    func pthreadUnlock() {
        let status = pthread_rwlock_unlock(rwLock)
        assert(status == 0, "pthread_rwlock_unlock failed with status \(status)")
    }

    func pthreadDeinit() {
        let status = pthread_rwlock_destroy(rwLock)
        assert(status == 0)
        rwLock.deallocate()
    }
}
