//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import CoreBluetooth
import SpeziFoundation


private protocol DecodableCharacteristic: Actor {
    func handleUpdateValueAssumingIsolation(_ data: Data?)
}

private protocol PrimitiveDecodableCharacteristic {
    func decodePrimitiveValue<ValueType>(from data: Data, as value: ValueType.Type) -> ValueType?
}


/// Captures and synchronizes access to the state of a ``Characteristic`` property wrapper.
actor CharacteristicPeripheralInjection<Value>: BluetoothActor {
    let bluetoothQueue: DispatchSerialQueue

    fileprivate let peripheral: BluetoothPeripheral
    let serviceId: CBUUID
    let characteristicId: CBUUID

    /// Observable value. Don't access directly.
    private let _value: ObservableBox<Value?>
    /// Don't access directly. Observable for the properties of ``CharacteristicAccessor``.
    private let _characteristic: WeakObservableBox<GATTCharacteristic>

    /// State support for control point characteristics.
    ///
    /// Fore more information see ``ControlPointCharacteristic``.
    private var controlPointTransaction: ControlPointTransaction<Value>?

    /// The user supplied onChange closure we use to forward notifications.
    private var onChangeClosure: ChangeClosureState<Value>
    /// The registration object we received from the ``BluetoothPeripheral`` for our instance onChange handler.
    private var instanceRegistration: OnChangeRegistration?
    /// The registration object we received from the ``BluetoothPeripheral`` for our value onChange handler.
    private var valueRegistration: OnChangeRegistration?


    private(set) var value: Value? {
        get {
            _value.value
        }
        set {
            _value.value = newValue
        }
    }

    private var characteristic: GATTCharacteristic? {
        get {
            _characteristic.value
        }
        set {
            _characteristic.value = newValue
        }
    }

    nonisolated var unsafeCharacteristic: GATTCharacteristic? {
        _characteristic.value
    }


    init(
        peripheral: BluetoothPeripheral,
        serviceId: CBUUID,
        characteristicId: CBUUID,
        value: ObservableBox<Value?>,
        characteristic: GATTCharacteristic?,
        onChangeClosure: OnChangeClosure<Value>?
    ) {
        self.bluetoothQueue = peripheral.bluetoothQueue
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.characteristicId = characteristicId
        self._value = value
        self._characteristic = .init(characteristic)
        self.onChangeClosure = onChangeClosure.map { .value($0) } ?? .none
    }

    /// Setup the injection. Must be called after initialization to set up all handlers and write the initial value.
    /// - Parameter defaultNotify: Flag indicating if notification handlers should be registered immediately.
    func setup(defaultNotify: Bool) {
        registerCharacteristicInstanceChanges()

        guard self is DecodableCharacteristic else {
            return
        }
        // value is readable!

        // handle assigning the initial value!
        if let characteristic,
           let value = characteristic.value {
            handleUpdatedValue(value)
        }

        self.registerCharacteristicValueChanges()

        if defaultNotify {
            enableNotifications()
        }
    }

    /// Signal from the Bluetooth state to cleanup the device
    func clearState() {
        self.instanceRegistration?.cancel()
        self.instanceRegistration = nil
        self.valueRegistration?.cancel()
        self.valueRegistration = nil
        self.onChangeClosure = .cleared // might contain a self reference, so we need to clear that!
    }


    func setOnChangeClosure(_ closure: OnChangeClosure<Value>) {
        if case .cleared = onChangeClosure {
            // object is about to be cleared. Make sure we don't create a self reference last minute.
            return
        }
        self.onChangeClosure = .value(closure)

        // if configured as initial, and there is a value, we notify
        if let value, closure.initial {
            Task { @SpeziBluetooth in
                await closure(value)
            }
        }
    }

    /// Enable or disable notifications for the characteristic.
    /// - Parameter enabled: Flag indicating if notifications should be enabled.
    func enableNotifications(_ enabled: Bool = true) {
        peripheral.assumeIsolated { peripheral in
            peripheral.enableNotifications(enabled, serviceId: serviceId, characteristicId: characteristicId)
        }
    }

    private func registerCharacteristicInstanceChanges() {
        self.instanceRegistration = peripheral.assumeIsolated { peripheral in
            peripheral.registerOnChangeCharacteristicHandler(
                service: serviceId,
                characteristic: characteristicId
            ) { [weak self] characteristic in
                guard let self = self else {
                    return
                }

                self.assertIsolated("BluetoothPeripheral onChange handler was unexpectedly executed outside the peripheral actor!")
                self.assumeIsolated { injection in
                    injection.handleChangedCharacteristic(characteristic)
                }
            }
        }
    }

    private func registerCharacteristicValueChanges() {
        self.valueRegistration = peripheral.assumeIsolated { peripheral in
            peripheral.registerOnChangeHandler(service: serviceId, characteristic: characteristicId) { [weak self] data in
                guard let self = self else {
                    return
                }
                self.assertIsolated("BluetoothPeripheral onChange handler was unexpectedly executed outside the peripheral actor!")
                self.assumeIsolated { injection in
                    injection.handleUpdatedValue(data)
                }
            }
        }
    }

    private func handleChangedCharacteristic(_ characteristic: GATTCharacteristic?) {
        // This the characteristic reference change?
        let instanceChanged = switch (self.characteristic, characteristic) {
        case let (.some(lhs), .some(rhs)):
            lhs.underlyingCharacteristic !== rhs.underlyingCharacteristic
        case (.some, .none):
            true
        case (.none, .some):
            true
        case (.none, .none):
            false
        }

        if self.characteristic != characteristic {
            self.characteristic = characteristic
        }

        if instanceChanged {
            if let characteristic {
                if let value = characteristic.value {
                    handleUpdatedValue(value)
                }
            } else {
                // we must make sure to not override the default value if one is present
                self.value = nil
            }
        }
    }

    private func handleUpdatedValue(_ data: Data?) {
        guard let decodable = self as? DecodableCharacteristic else {
            return
        }

        decodable.assumeIsolated { decodable in
            decodable.handleUpdateValueAssumingIsolation(data)
        }
    }

    private func dispatchChangeHandler(previous previousValue: Value?, new newValue: Value, with onChangeClosure: ChangeClosureState<Value>) async {
        guard case let .value(closure) = onChangeClosure else {
            return
        }

        if closure.initial || previousValue != nil {
            await closure(newValue)
        }
    }
}


extension CharacteristicPeripheralInjection: DecodableCharacteristic where Value: ByteDecodable {
    func handleUpdateValueAssumingIsolation(_ data: Data?) {
        if let data {
            guard let value = decodeValue(from: data) else {
                Bluetooth.logger.error("Could decode updated value for characteristic \(self.characteristic?.debugDescription ?? self.characteristicId.uuidString). Invalid format!")
                return
            }

            let previousValue = self.value
            self.value = value

            self.fullFillControlPointRequest(value)

            let onChangeClosure = onChangeClosure // make sure we capture it now, not later where it might have changed.
            Task { @SpeziBluetooth in
                await self.dispatchChangeHandler(previous: previousValue, new: value, with: onChangeClosure)
            }
        } else {
            self.value = nil
        }
    }
}


extension CharacteristicPeripheralInjection: PrimitiveDecodableCharacteristic where Value: PrimitiveByteDecodable {
    fileprivate nonisolated func decodePrimitiveValue<ValueType>(from data: Data, as value: ValueType.Type) -> ValueType? {
        guard let value = Value(data: data, endianness: .little) as? ValueType else {
            preconditionFailure("Type \(Value.self) doesn't match requested \(ValueType.self).")
        }
        return value
    }
}


extension CharacteristicPeripheralInjection where Value: ByteDecodable {
    fileprivate func decodeValue(from data: Data) -> Value? {
        if let injection = self as? (any PrimitiveDecodableCharacteristic) {
            return injection.decodePrimitiveValue(from: data, as: Value.self)
        }
        return Value(data: data)
    }
}


extension CharacteristicPeripheralInjection where Value: ByteEncodable {
    fileprivate func encodeValue(_ value: Value) -> Data {
        if let primitiveValue = value as? PrimitiveByteEncodable {
            return primitiveValue.encode(endianness: .little)
        }
        return value.encode()
    }
}


// MARK: - Accessors Support

extension CharacteristicPeripheralInjection where Value: ByteDecodable {
    func read() async throws -> Value {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        let data = try await peripheral.read(characteristic: characteristic)
        guard let value = decodeValue(from: data) else {
            throw BluetoothError.incompatibleDataFormat
        }

        return value
    }
}


extension CharacteristicPeripheralInjection where Value: ByteEncodable {
    func write(_ value: Value) async throws {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        let data = encodeValue(value)
        try await peripheral.write(data: data, for: characteristic)
        self.value = value
    }

    func writeWithoutResponse(_ value: Value) async throws {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        let data = encodeValue(value)
        await peripheral.writeWithoutResponse(data: data, for: characteristic)
        self.value = value
    }
}

// MARK: - Control Point Support

extension CharacteristicPeripheralInjection where Value: ControlPointCharacteristic {
    func sendRequest(_ value: Value, timeout: Duration = .seconds(20)) async throws -> Value {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        if !characteristic.isNotifying { // shortcut that doesn't require actor isolation.
            // It takes some time for the characteristic to acknowledge notification registration. Assuming the characteristic was injected,
            // and notifications were requests is good enough for us to assume we will receive the notification. Allows to send request much earlier.
            guard await peripheral.didRequestNotifications(serviceId: serviceId, characteristicId: characteristicId) else {
                throw BluetoothError.controlPointRequiresNotifying(service: serviceId, characteristic: characteristicId)
            }
        }

        guard controlPointTransaction == nil else {
            throw BluetoothError.controlPointInProgress(service: serviceId, characteristic: characteristicId)
        }

        let transaction = ControlPointTransaction<Value>()
        self.controlPointTransaction = transaction

        defer {
            if controlPointTransaction?.id == transaction.id {
                controlPointTransaction = nil
            }
        }

        // make sure we are ready to receive the response
        async let response = controlPointContinuationTask(transaction)

        do {
            try await write(value)
        } catch {
            transaction.signalCancellation()
            _ = try? await response // await response to avoid cancellation
            
            throw error
        }

        async let _ = withTimeout(of: timeout) {
            transaction.signalTimeout()
        }

        return try await response
    }

    private func controlPointContinuationTask(_ transaction: ControlPointTransaction<Value>) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                transaction.assignContinuation(continuation)
            }
        } onCancel: {
            transaction.signalCancellation()
        }
    }
}


extension CharacteristicPeripheralInjection {
    fileprivate func fullFillControlPointRequest(_ value: Value) {
        if let controlPointTransaction {
            controlPointTransaction.fulfill(value)
            self.controlPointTransaction = nil
        }
    }
}
