//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// An active registration of a on-change handler.
///
/// This object represents an active registration of an on-change handler. Primarily, this can be used to keep
/// track of a on-change handler and cancel the registration at a later point.
///
/// - Tip: The on-change handler will be automatically unregistered when this object is deallocated.
public final class OnChangeRegistration {
    // reference counting is atomic, so non-isolated(unsafe) is fine, we never mutate
    private nonisolated(unsafe) weak var peripheral: BluetoothPeripheral?
    let locator: CharacteristicLocator
    let handlerId: UUID


    init(peripheral: BluetoothPeripheral?, locator: CharacteristicLocator, handlerId: UUID) {
        self.peripheral = peripheral
        self.locator = locator
        self.handlerId = handlerId
    }


    /// Cancel the on-change handler registration.
    public func cancel() {
        Task { @SpeziBluetooth in
            peripheral?.deregisterOnChange(self)
        }
    }


    deinit {
        // make sure we don't capture self after this deinit
        let peripheral = peripheral
        let locator = locator
        let handlerId = handlerId

        Task.detached { @Sendable @SpeziBluetooth in
            peripheral?.deregisterOnChange(locator: locator, handlerId: handlerId)
        }
    }
}


extension OnChangeRegistration: Sendable {}
