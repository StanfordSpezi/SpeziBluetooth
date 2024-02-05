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

    init(device: UUID, manager: BluetoothManager, handler: @escaping (isolated BluetoothManager) -> Void) {
        // make sure that you don't create a reference cycle through the closure above!

        self.targetDevice = device
        self.workItem = BluetoothWorkItem(manager: manager, handler: handler)
    }


    func cancel() {
        workItem.cancel()
    }

    func schedule(for timeout: TimeInterval, in queue: BluetoothSerialExecutor) {
        // `DispatchTime` only allows for integer time
        let milliSeconds = Int(timeout * 1000)
        queue.schedule(for: .now() + .milliseconds(milliSeconds), execute: workItem)
    }

    deinit {
        cancel()
    }
}
