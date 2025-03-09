//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@testable import SpeziBluetooth
import Testing


@Suite("RWLock", .timeLimit(.minutes(1)))
struct RWLockTests {
    @Test("Concurrent Reads")
    func testConcurrentReads() async {
        let lock = RWLock()

        async let handle0: Void = confirmation { confirmation in
            lock.withReadLock {
                usleep(100_000) // Simulate read delay (200ms)
                confirmation()
            }
        }

        async let handle1: Void = confirmation { confirmation in
            lock.withReadLock {
                usleep(100_000) // Simulate read delay (200ms)
                confirmation()
            }
        }

        _ = await (handle0, handle1)
    }

    @Test("Write Blocks Other Writes")
    func testWriteBlocksOtherWrites() async throws {
        let lock = RWLock()

        async let handle0: Void = confirmation { confirmation in
            lock.withWriteLock {
                usleep(200_000) // Simulate write delay (200ms)
                confirmation()
            }
        }

        async let handle1: Void = confirmation { confirmation in
            try await Task.sleep(for: .milliseconds(100))
            lock.withWriteLock {
                confirmation()
            }
        }

        _ = try await (handle0, handle1)
    }

    @Test("Write Blocks Reads")
    func testWriteBlocksReads() async throws {
        let lock = RWLock()

        async let handle0: Void = confirmation { confirmation in
            lock.withWriteLock {
                usleep(200_000) // Simulate write delay (200ms)
                confirmation()
            }
        }

        async let handle1: Void = confirmation { confirmation in
            try await Task.sleep(for: .milliseconds(100))
            lock.withReadLock {
                confirmation()
            }
        }

        _ = try await (handle0, handle1)
    }

    @Test("Is Write Locked")
    func testIsWriteLocked() {
        let lock = RWLock()

        Task.detached {
            lock.withWriteLock {
                #expect(lock.isWriteLocked())
                usleep(100_000) // Simulate write delay (100ms)
            }
        }

        usleep(50_000) // Give the other thread time to lock (50ms)
        #expect(!lock.isWriteLocked())
    }

    @Test("Multiple Locks Acquired")
    func testMultipleLocksAcquired() async {
        let lock1 = RWLock()
        let lock2 = RWLock()

        await confirmation { confirmation in
            lock1.withReadLock {
                lock2.withReadLock {
                    confirmation()
                }
            }
        }
    }


    @Test("Concurrent Reads Recursive")
    func testConcurrentReadsRecursive() async {
        let lock = RecursiveRWLock()

        async let handle0: Void = confirmation { confirmation in
            lock.withReadLock {
                usleep(100_000) // Simulate read delay 100 ms
                confirmation()
            }
        }

        async let handle1: Void = confirmation { confirmation in
            lock.withReadLock {
                usleep(100_000) // Simulate read delay 100ms
                confirmation()
            }
        }

        _ = await (handle0, handle1)
    }

    @Test("Write Blocks Other Writes Recursive")
    func testWriteBlocksOtherWritesRecursive() async throws {
        let lock = RecursiveRWLock()

        async let handle0: Void = confirmation { confirmation in
            lock.withWriteLock {
                usleep(200_000) // Simulate write delay 200ms
                confirmation()
            }
        }

        async let handle1: Void = confirmation { confirmation in
            try await Task.sleep(for: .milliseconds(100))
            lock.withWriteLock {
                confirmation()
            }
        }

        _ = try await (handle0, handle1)
    }

    @Test("Write Blocks Reads Recursive")
    func testWriteBlocksReadsRecursive() async throws {
        let lock = RecursiveRWLock()

        async let handle0: Void = confirmation { confirmation in
            lock.withWriteLock {
                usleep(200_000) // Simulate write delay 200 ms
                confirmation()
            }
        }

        async let handle1: Void = confirmation { confirmation in
            try await Task.sleep(for: .milliseconds(100))
            lock.withReadLock {
                confirmation()
            }
        }

        _ = try await (handle0, handle1)
    }

    @Test("Multiple Locks Acquired Recursive")
    func testMultipleLocksAcquiredRecursive() async {
        let lock1 = RecursiveRWLock()
        let lock2 = RecursiveRWLock()

        await confirmation { confirmation in
            lock1.withReadLock {
                lock2.withReadLock {
                    confirmation()
                }
            }
        }
    }

    @Test("Recursive Read Acquisition")
    func testRecursiveReadReadAcquisition() async {
        let lock = RecursiveRWLock()

        await confirmation { confirmation in
            lock.withReadLock {
                lock.withReadLock {
                    confirmation()
                }
            }
        }
    }

    @Test("Recursive Write Acquisition")
    func testRecursiveWriteRecursiveAcquisition() async throws {
        let lock = RecursiveRWLock()

        async let handle0: Void = confirmation(expectedCount: 4) { confirmation in
            lock.withWriteLock {
                usleep(50_000) // Simulate write delay 50 ms
                lock.withReadLock {
                    confirmation()
                    usleep(200_000) // Simulate write delay 200 ms
                    lock.withWriteLock {
                        confirmation()
                    }
                }

                lock.withWriteLock {
                    usleep(200_000) // Simulate write delay 200 ms
                    lock.withReadLock {
                        confirmation()
                    }
                    confirmation()
                }
            }
        }

        // race
        async let handle1: Void = confirmation { confirmation in
            try await withThrowingDiscardingTaskGroup { group in
                for _ in 0..<10 {
                    group.addTask {
                        // random sleep up to 50 ms
                        try await Task.sleep(nanoseconds: UInt64.random(in: 0...50_000_000))
                        lock.withWriteLock {
                            _ = usleep(100)
                        }
                    }
                }
            }

            confirmation()
        }

        _ = try await (handle0, handle1)
    }
}
