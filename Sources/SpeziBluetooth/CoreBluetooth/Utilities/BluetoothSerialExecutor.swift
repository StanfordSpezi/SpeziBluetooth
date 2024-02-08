//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class BluetoothSerialExecutor: SerialExecutor {
    private let dispatchQueue: DispatchSerialQueue
    var unsafeDispatchQueue: DispatchSerialQueue {
        dispatchQueue
    }

    init(copy executor: BluetoothSerialExecutor) {
        self.dispatchQueue = executor.dispatchQueue
    }

    init(dispatchQueue: DispatchSerialQueue) {
        self.dispatchQueue = dispatchQueue
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(complexEquality: self)
    }

    func isSameExclusiveExecutionContext(other: BluetoothSerialExecutor) -> Bool {
        print("Checked for equality")
        return dispatchQueue == other.dispatchQueue
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(consume job)
        dispatchQueue.async {
            unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    func schedule(for deadline: DispatchTime, execute: BluetoothWorkItem) {
        dispatchQueue.asyncAfter(deadline: deadline, execute: execute.workItem)
    }
}
