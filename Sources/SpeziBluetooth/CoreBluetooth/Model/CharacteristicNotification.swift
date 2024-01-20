//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// An active registration of a notification handler.
///
/// This object represents an active registration of an notification handler. Primarily, this can be used to keep
/// track of a notification handler and cancel the registration at a later point.
///
/// - Tip: The notification handler will be automatically unregistered when this object is deallocated.
public class CharacteristicNotification {
    private weak var peripheral: BluetoothPeripheral?
    let locator: CharacteristicLocator
    let handlerId: UUID


    init(peripheral: BluetoothPeripheral?, locator: CharacteristicLocator, handlerId: UUID) {
        self.peripheral = peripheral
        self.locator = locator
        self.handlerId = handlerId
    }


    /// Cancel the notification handler registration.
    public func cancel() async {
        await peripheral?.deregisterNotification(self)
    }


    deinit {
        // make sure we don't capture self after this deinit
        let peripheral = peripheral
        let locator = locator
        let handlerId = handlerId

        Task {
            await peripheral?.deregisterNotification(locator: locator, handlerId: handlerId)
        }
    }
}
