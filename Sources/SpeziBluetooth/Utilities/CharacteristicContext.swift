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


/// Captures and synchronized access to the state of a ``Characteristic`` property wrapper.
actor CharacteristicContext<Value> {
    let peripheral: BluetoothPeripheral
    let characteristicId: CBUUID
    let serviceId: CBUUID

    private let characteristicBox: OptionalBox<CBCharacteristic>
    private let valueBox: OptionalBox<Value>

    private var notify = false
    private var registration: CharacteristicNotification?

    nonisolated var characteristic: CBCharacteristic? { // nil if device is not connected yet
        characteristicBox.value
    }

    nonisolated var value: Value? {
        valueBox.value
    }


    init(
        peripheral: BluetoothPeripheral,
        serviceId: CBUUID,
        characteristicId: CBUUID,
        characteristic: CBCharacteristic?
    ) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.characteristicId = characteristicId
        self.characteristicBox = OptionalBox(value: characteristic)
        self.valueBox = OptionalBox(value: nil)
    }

    /// Setup the context. Must be called after initialization to set up all handlers and write the initial value.
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
            _ = peripheral.services
        } onChange: { [weak self] in
            Task { [weak self] in
                await self?.handleServicesChange()
            }
            self?.trackServicesUpdates()
        }
    }

    private func handleServicesChange() {
        let service = peripheral.services?.first(where: { $0.uuid == serviceId })
        let characteristic = service?.characteristics?.first(where: { $0.uuid == characteristicId })

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


extension CharacteristicContext: DecodableCharacteristic where Value: ByteDecodable {
    nonisolated func handleUpdateValueAssumingIsolation(_ data: Data?) {
        // assumes this is called with actor isolation!
        if let data {
            guard let value = Value(data: data) else {
                // TODO: make it a warning!!!
                return
            }

            self.valueBox.value = value
        } else {
            self.valueBox.value = nil
        }
    }
}
