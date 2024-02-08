//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


class BluetoothWorkItem {
    let workItem: DispatchWorkItem

    init(manager: BluetoothManager, handler: @escaping (isolated BluetoothManager) -> Void) {
        self.workItem = DispatchWorkItem { [weak manager] in
            guard let manager else {
                return
            }

            // We are running on the dispatch queue, however we are not running in the task.
            // So sadly, we can't just jump into the actor isolation. But no big deal here for synchronization.

            Task { @SpeziBluetooth in
                await manager.isolated(perform: handler)
            }
        }
    }

    func cancel() {
        workItem.cancel()
    }
}


extension DispatchSerialQueue {
    func schedule(for deadline: DispatchTime, execute: BluetoothWorkItem) {
        asyncAfter(deadline: deadline, execute: execute.workItem)
    }
}
