//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


private protocol DecodableCharacteristic {
    func handleUpdateValueAssumingIsolation(_ data: Data?)
}


@Observable
private class NonIsolatedState<Value> {
    weak var characteristic: GATTCharacteristic?

    /// The user supplied onChange closure we use to forward notifications.
    @ObservationIgnored var onChangeClosure: ((Value) -> Void)?
    /// The registration object we received from the ``BluetoothPeripheral`` for our onChange handler.
    @ObservationIgnored var registration: OnChangeRegistration?


    init(characteristic: GATTCharacteristic?, onChangeClosure: ((Value) -> Void)?) {
        self.characteristic = characteristic
        self.onChangeClosure = onChangeClosure
    }
}


/// Captures and synchronizes access to the state of a ``Characteristic`` property wrapper.
actor CharacteristicPeripheralInjection<Value> {
    let peripheral: BluetoothPeripheral
    let serviceId: CBUUID
    let characteristicId: CBUUID
    let valueBox: Characteristic<Value>.ValueBox

    private let state: NonIsolatedState<Value>

    /// This flag controls if we are supposed to be subscribed to characteristic notifications.
    private var notify = false

    /// `nil` if device is not connected or characteristic not discovered yet/
    nonisolated var characteristic: GATTCharacteristic? {
        state.characteristic
    }


    init(
        peripheral: BluetoothPeripheral,
        serviceId: CBUUID,
        characteristicId: CBUUID,
        valueBox: Characteristic<Value>.ValueBox,
        characteristic: GATTCharacteristic?,
        onChangeClosure: ((Value) -> Void)?
    ) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.characteristicId = characteristicId
        self.valueBox = valueBox
        self.state = NonIsolatedState(characteristic: characteristic, onChangeClosure: onChangeClosure)
    }

    /// Setup the injection. Must be called after initialization to set up all handlers and write the initial value.
    /// - Parameter defaultNotify: Flag indicating if notification handlers should be registered immediately.
    func setup(defaultNotify: Bool) async {
        trackServicesUpdates() // enable observation tracking for peripheral.services and characteristic properties

        guard let instance = self as? DecodableCharacteristic else {
            return
        }
        // value is readable!

        // handle assigning the initial value!
        if let characteristic,
           let value = characteristic.value {
            instance.handleUpdateValueAssumingIsolation(value)
        }

        // register onChange handler
        self.state.registration = await peripheral.registerOnChangeHandler(service: serviceId, characteristic: characteristicId) { [weak self] data in
            Task { [weak self] in
                await self?.handleUpdatedValue(data)
            }
        }

        if defaultNotify {
            await enableNotifications()
        }
    }

    /// Signal from the Bluetooth state to cleanup the device
    nonisolated func clearState() {
        self.state.registration?.cancel()
        self.state.registration = nil
        self.state.onChangeClosure = nil // might contain a self reference, so we need to clear that!
    }

    nonisolated func setOnChangeClosure(_ closure: ((Value) -> Void)?) {
        self.state.onChangeClosure = closure
    }

    /// Enable or disable notifications (if not already) for the characteristic.
    /// - Parameter enabled: Flag indicating if notifications should be enabled.
    func enableNotifications(_ enabled: Bool = true) async {
        guard notify != enabled else {
            return
        }

        self.notify = enabled
        await peripheral.enableNotifications(enabled, serviceId: serviceId, characteristicId: characteristicId)
    }

    private nonisolated func trackServicesUpdates() {
        withObservationTracking {
            _ = peripheral.getCharacteristic(id: characteristicId, on: serviceId)
        } onChange: { [weak self] in
            Task { [weak self] in
                // we need to wait before registering, such that we register `.characteristic` property once the service becomes present
                self?.trackServicesUpdates()
                await self?.handleServicesChange()
            }
        }
    }

    private func handleServicesChange() {
        let characteristic = peripheral.getCharacteristic(id: characteristicId, on: serviceId)

        let instanceChanged = state.characteristic?.underlyingCharacteristic !== characteristic?.underlyingCharacteristic
        state.characteristic = characteristic

        if instanceChanged {
            if let characteristic {
                // TODO: this seems to be flacky?
                print("We are writing a default value \(characteristic.value) for \(characteristicId)")
                handleUpdatedValue(characteristic.value)
            } else {
                // we must make sure to not override the default value is one is present
                valueBox.value = nil
            }
        }
    }

    private func handleUpdatedValue(_ data: Data?) {
        guard let decodable = self as? DecodableCharacteristic else {
            return
        }

        // TODO: are we saving the written value?
        decodable.handleUpdateValueAssumingIsolation(data)
    }
}


extension CharacteristicPeripheralInjection: DecodableCharacteristic where Value: ByteDecodable {
    nonisolated func handleUpdateValueAssumingIsolation(_ data: Data?) {
        assertIsolated("\(#function) was called without actor isolation.")
        if let data {
            guard let value = Value(data: data) else {
                Bluetooth.logger.error("Could decode updated value for characteristic \(self.characteristic?.debugDescription ?? self.characteristicId.uuidString). Invalid format!")
                return
            }

            self.valueBox.value = value
            if let handler = state.onChangeClosure {
                handler(value)
            }
        } else {
            self.valueBox.value = nil
        }
    }
}
