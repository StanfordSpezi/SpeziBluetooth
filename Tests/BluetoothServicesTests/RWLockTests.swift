//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziBluetooth
import XCTest


final class RWLockTests: XCTestCase {
    func testConcurrentReads() {
        let lock = RWLock()
        let expectation1 = self.expectation(description: "First read")
        let expectation2 = self.expectation(description: "Second read")

        Task.detached {
            lock.withReadLock {
                usleep(100_000) // Simulate read delay
                expectation1.fulfill()
            }
        }

        Task.detached {
            lock.withReadLock {
                usleep(100_000) // Simulate read delay
                expectation2.fulfill()
            }
        }

        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    func testWriteBlocksOtherWrites() {
        let lock = RWLock()
        let expectation1 = self.expectation(description: "First write")
        let expectation2 = self.expectation(description: "Second write")

        Task.detached {
            lock.withWriteLock {
                usleep(200_000) // Simulate write delay
                expectation1.fulfill()
            }
        }

        Task.detached {
            try await Task.sleep(for: .milliseconds(100))
            lock.withWriteLock {
                expectation2.fulfill()
            }
        }

        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    func testWriteBlocksReads() {
        let lock = RWLock()
        let expectation1 = self.expectation(description: "Write")
        let expectation2 = self.expectation(description: "Read")

        Task.detached {
            lock.withWriteLock {
                usleep(200_000) // Simulate write delay
                expectation1.fulfill()
            }
        }

        Task.detached {
            try await Task.sleep(for: .milliseconds(100))
            lock.withReadLock {
                expectation2.fulfill()
            }
        }

        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    func testIsWriteLocked() {
        let lock = RWLock()

        Task.detached {
            lock.withWriteLock {
                XCTAssertTrue(lock.isWriteLocked())
                usleep(100_000) // Simulate write delay
            }
        }

        usleep(50_000) // Give the other thread time to lock
        XCTAssertFalse(lock.isWriteLocked())
    }

    func testMultipleLocksAcquired() {
        let lock1 = RWLock()
        let lock2 = RWLock()
        let expectation1 = self.expectation(description: "Read")

        Task.detached {
            lock1.withReadLock {
                lock2.withReadLock {
                    expectation1.fulfill()
                }
            }
        }

        wait(for: [expectation1], timeout: 1.0)
    }
}
