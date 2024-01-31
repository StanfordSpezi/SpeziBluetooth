//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


private protocol DecodableCharacteristic {
    @MainActor
    func handleUpdateValueAssumingIsolation(_ data: Data?) async
}


/// Captures and synchronizes access to the state of a ``Characteristic`` property wrapper.
@Observable
class CharacteristicPeripheralInjection<Value> {
    let peripheral: BluetoothPeripheral
    let serviceId: CBUUID
    let characteristicId: CBUUID
    let valueBox: Characteristic<Value>.ValueBox

    // Updates must only happen through update(characteristic:)
    private(set) weak var characteristic: GATTCharacteristic?

    /// The user supplied onChange closure we use to forward notifications.
    @ObservationIgnored var onChangeClosure: ((Value) async -> Void)?
    /// The registration object we received from the ``BluetoothPeripheral`` for our onChange handler.
    @ObservationIgnored var registration: OnChangeRegistration?


    init(
        peripheral: BluetoothPeripheral,
        serviceId: CBUUID,
        characteristicId: CBUUID,
        valueBox: Characteristic<Value>.ValueBox,
        characteristic: GATTCharacteristic?,
        onChangeClosure: ((Value) async -> Void)?
    ) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.characteristicId = characteristicId
        self.valueBox = valueBox
        self.characteristic = characteristic
        self.onChangeClosure = onChangeClosure
    }

    /// Setup the injection. Must be called after initialization to set up all handlers and write the initial value.
    /// - Parameter defaultNotify: Flag indicating if notification handlers should be registered immediately.
    @MainActor
    func setup(defaultNotify: Bool) async {
        trackServicesUpdates() // enable observation tracking for peripheral.services and characteristic properties

        guard let instance = self as? DecodableCharacteristic else {
            return
        }
        // value is readable!

        // handle assigning the initial value!
        if let characteristic,
           let value = characteristic.value {
            await instance.handleUpdateValueAssumingIsolation(value)
        }

        // register onChange handler
        self.registration = await peripheral.registerOnChangeHandler(service: serviceId, characteristic: characteristicId) { [weak self] data in
            Task { @MainActor [weak self] in
                await self?.handleUpdatedValue(data)
            }
        }

        if defaultNotify {
            await enableNotifications()
        }
    }

    /// Signal from the Bluetooth state to cleanup the device
    @MainActor
    func clearState() {
        self.registration?.cancel()
        self.registration = nil
        self.onChangeClosure = nil // might contain a self reference, so we need to clear that!
    }

    @MainActor
    private func update(characteristic: GATTCharacteristic?) {
        if self.characteristic != characteristic {
            self.characteristic = characteristic
        }
    }

    nonisolated func setOnChangeClosure(_ closure: ((Value) -> Void)?) {
        self.onChangeClosure = closure
    }

    /// Enable or disable notifications for the characteristic.
    /// - Parameter enabled: Flag indicating if notifications should be enabled.
    func enableNotifications(_ enabled: Bool = true) async {
        await peripheral.enableNotifications(enabled, serviceId: serviceId, characteristicId: characteristicId)
    }

    /// Observes a write to the characteristics and saves the written value to the local storage.
    func observeWrite(of value: Value, action: () async throws -> Void) async rethrows {
        try await action()
        await valueBox.update(value: value) // if write was successful, we save it in the property
    }

    @MainActor
    private func trackServicesUpdates() {
        withObservationTracking {
            _ = peripheral.getCharacteristic(id: characteristicId, on: serviceId)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                // we need to wait before registering, such that we register `.characteristic` property once the service becomes present
                self?.trackServicesUpdates()
                await self?.handleServicesChange()
            }
        }
    }

    @MainActor
    private func handleServicesChange() async {
        let characteristic = peripheral.getCharacteristic(id: characteristicId, on: serviceId)

        let instanceChanged = self.characteristic?.underlyingCharacteristic !== characteristic?.underlyingCharacteristic
        update(characteristic: characteristic)

        if instanceChanged {
            if let characteristic {
                await handleUpdatedValue(characteristic.value)
            } else {
                // we must make sure to not override the default value is one is present
                valueBox.update(value: nil)
            }
        }
    }

    @MainActor
    private func handleUpdatedValue(_ data: Data?) async {
        guard let decodable = self as? DecodableCharacteristic else {
            return
        }

        await decodable.handleUpdateValueAssumingIsolation(data)
    }
}


extension CharacteristicPeripheralInjection: DecodableCharacteristic where Value: ByteDecodable {
    @MainActor
    func handleUpdateValueAssumingIsolation(_ data: Data?) async {
        if let data {
            guard let value = Value(data: data) else {
                Bluetooth.logger.error("Could decode updated value for characteristic \(self.characteristic?.debugDescription ?? self.characteristicId.uuidString). Invalid format!")
                return
            }

            self.valueBox.update(value: value)
            if let handler = onChangeClosure {
                // We specifically create a dedicated Task for every updated value, so we can stay on the same task
                // without blocking anything for the onChange handler.
                await handler(value)
            }
        } else {
            self.valueBox.update(value: nil)
        }
    }
}
