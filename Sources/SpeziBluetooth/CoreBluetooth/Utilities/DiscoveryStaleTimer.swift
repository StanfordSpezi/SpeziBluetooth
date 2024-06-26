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
    private let workItem: BluetoothWorkItem

    init<Actor: BluetoothActor>(device: UUID, boundTo actor: Actor, handler: @escaping (isolated Actor) -> Void) {
        // make sure that you don't create a reference cycle through the closure above!

        self.targetDevice = device
        self.workItem = BluetoothWorkItem(boundTo: actor, handler: handler)
    }


    func cancel() {
        workItem.cancel()
    }

    func schedule(for timeout: TimeInterval, in queue: DispatchSerialQueue) {
        // `DispatchTime` only allows for integer time
        let milliSeconds = Int(timeout * 1000)
        queue.schedule(for: .now() + .milliseconds(milliSeconds), execute: workItem)
    }

    deinit {
        cancel()
    }
}
