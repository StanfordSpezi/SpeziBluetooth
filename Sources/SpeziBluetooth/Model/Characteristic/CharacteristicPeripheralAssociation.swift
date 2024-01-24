//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// Indirect storage box to support a write-only lock with eventual consistent reads.
class OptionalBox<Value> {
    fileprivate(set) var value: Value?

    init(value: Value?) {
        self.value = value
    }
}


private protocol DecodableCharacteristic {
    func handleUpdateValueAssumingIsolation(_ data: Data?)
}


/// Captures and synchronizes access to the state of a ``Characteristic`` property wrapper.
actor CharacteristicPeripheralAssociation<Value> {
    let peripheral: BluetoothPeripheral
    let characteristicId: CBUUID
    let serviceId: CBUUID

    private let characteristicBox: OptionalBox<GATTCharacteristic> // TODO store the characteristic weak!
    private let valueBox: OptionalBox<Value>

    /// This flag controls if we are supposed to be subscribed to characteristic notifications.
    private var notify = false
    /// The registration object we received from the ``BluetoothPeripheral`` for our notification handler.
    private var registration: CharacteristicNotification?
    /// The user supplied notification closure we use to forward notifications.
    private let notificationClosure: OptionalBox<(Value) -> Void>

    nonisolated var characteristic: GATTCharacteristic? { // nil if device is not connected or characteristic not discovered yet
        characteristicBox.value
    }

    nonisolated var value: Value? {
        valueBox.value
    }


    init(
        peripheral: BluetoothPeripheral,
        serviceId: CBUUID,
        characteristicId: CBUUID,
        characteristic: GATTCharacteristic?,
        notificationClosure: ((Value) -> Void)?
    ) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.characteristicId = characteristicId
        self.characteristicBox = OptionalBox(value: characteristic)
        self.valueBox = OptionalBox(value: nil)
        self.notificationClosure = OptionalBox(value: notificationClosure)
    }

    /// Setup the association. Must be called after initialization to set up all handlers and write the initial value.
    /// - Parameter defaultNotify: Flag indicating if notification handlers should be registered immediately.
    func setup(defaultNotify: Bool) async {
        trackServicesUpdates() // enable observation tracking for peripheral.services

        if let instance = self as? DecodableCharacteristic { // Value is ByteDecodable!
            // handle assigning the initial value!
            if let characteristic,
               let value = characteristic.value {
                instance.handleUpdateValueAssumingIsolation(value)
            }

            if defaultNotify {
                await enableNotifications()
            }
        }
    }

    nonisolated func clearState() { // signal from the Bluetooth state to cleanup the device
        self.notificationClosure.value = nil // might contain a self reference!
    }

    nonisolated func setNotificationClosure(_ closure: ((Value) -> Void)?) {
        self.notificationClosure.value = closure
    }

    /// Enable notifications (if not already) for the characteristic.
    func enableNotifications() async {
        guard !notify else {
            return
        }

        self.notify = true

        let registration = await peripheral
            .registerNotifications(service: serviceId, characteristic: characteristicId) { [weak self] data in
                Task { [weak self] in
                    await self?.handleNotification(data)
                }
            }

        // we have a suspension point above, so we need to double check that our `notify` property is still true to catch any race conditions

        if notify {
            self.registration = registration
        } else {
            // notifications were disabled in the meantime. Remove our registration again.
            await registration.cancel()
        }
    }

    /// Disable notifications (if not already) for the characteristic.
    func disableNotifications() async {
        guard notify else {
            return
        }

        let registration = self.registration

        self.notify = false
        self.registration = nil

        await registration?.cancel()
    }

    private nonisolated func trackServicesUpdates() {
        withObservationTracking {
            _ = peripheral.getCharacteristic(id: characteristicId, on: serviceId)
        } onChange: { [weak self] in
            Task { [weak self] in
                await self?.handleServicesChange()
            }
            self?.trackServicesUpdates()
        }
    }

    private func handleServicesChange() {
        let characteristic = peripheral.getCharacteristic(id: characteristicId, on: serviceId)

        characteristicBox.value = characteristic

        if characteristic == nil { // device disconnected, remove the value
            valueBox.value = nil
        }
    }

    private func handleNotification(_ data: Data?) {
        guard let decodable = self as? DecodableCharacteristic else {
            return
        }

        decodable.handleUpdateValueAssumingIsolation(data)
    }
}


extension CharacteristicPeripheralAssociation: DecodableCharacteristic where Value: ByteDecodable {
    nonisolated func handleUpdateValueAssumingIsolation(_ data: Data?) {
        assertIsolated("\(#function) was called without actor isolation.")
        if let data {
            guard let value = Value(data: data) else {
                Bluetooth.logger.error("Could decode updated value for characteristic \(self.characteristic?.debugDescription ?? self.characteristicId.uuidString). Invalid format!")
                return
            }

            self.valueBox.value = value
            if let handler = notificationClosure.value {
                handler(value)
            }
        } else {
            self.valueBox.value = nil
        }
    }
}
