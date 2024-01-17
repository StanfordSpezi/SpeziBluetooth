//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


class DiscoveryStaleTimer {
    let targetDevice: UUID
    /// The dispatch work item that schedules the next stale timer.
    private let workItem: DispatchWorkItem

    init(device: UUID, handler: @escaping () -> Void) { // TODO: document reference cycle?
        self.targetDevice = device
        self.workItem = DispatchWorkItem { // we do not capture self here!!
            handler()
        }
    }


    func cancel() {
        workItem.cancel()
    }

    func schedule(for timeout: TimeInterval, in queue: DispatchQueue) {
        // `DispatchTime` only allows for integer time
        let milliSeconds = Int(timeout / 1000)
        queue.asyncAfter(deadline: .now() + .milliseconds(milliSeconds), execute: workItem)
    }

    deinit {
        cancel()
    }
}
