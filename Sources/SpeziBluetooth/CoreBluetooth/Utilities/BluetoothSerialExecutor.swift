//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation

class BluetoothWorkItem {
    fileprivate let workItem: DispatchWorkItem

    init(manager: BluetoothManager, handler: @escaping (isolated BluetoothManager) -> Void) {
        self.workItem = DispatchWorkItem { [weak manager] in
            // BluetoothWorkItem is only accepted by the `BluetoothSerialExecutor`, therefore we can assume isolation here
            manager?.assumeIsolated { manager in
                handler(manager)
            }
        }
    }

    func cancel() {
        workItem.cancel()
    }
}


final class BluetoothSerialExecutor: SerialExecutor {
    private let dispatchQueue: DispatchQueue

    var unsafeDispatchQueue: DispatchQueue {
        dispatchQueue
    }

    init(copy executor: BluetoothSerialExecutor) {
        self.dispatchQueue = executor.dispatchQueue
    }

    init(dispatchQueue: DispatchQueue) {
        self.dispatchQueue = dispatchQueue
    }

    func isSameExclusiveExecutionContext(other: BluetoothSerialExecutor) -> Bool {
        dispatchQueue == other.dispatchQueue
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
