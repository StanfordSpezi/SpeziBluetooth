//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


actor ServicePeripheralInjection {
    private let bluetoothExecutor: BluetoothSerialExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        bluetoothExecutor.asUnownedSerialExecutor()
    }

    private let peripheral: BluetoothPeripheral
    private let serviceId: CBUUID

    /// Do not access directly.
    private let _service: WeakObservableBox<GATTService>


    private(set) var service: GATTService? {
        get {
            _service.value
        }
        set {
            _service.value = newValue
        }
    }


    init(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: GATTService?) {
        self.bluetoothExecutor = BluetoothSerialExecutor(copy: peripheral.bluetoothExecutor)
        self.peripheral = peripheral
        self.serviceId = serviceId
        self._service = WeakObservableBox(service)
    }

    func setup() {
        trackServicesUpdate()
    }

    private func trackServicesUpdate() {
        // TODO: just register for services changes onChange(of: serviceId) { service in ... }
        // TODO: replace observation access!
        withObservationTracking {
            _ = peripheral.assumeIsolated { $0.getService(id: serviceId) }
        } onChange: { [weak self] in
            Task { [weak self] in
                await self?.handleServicesChange()
            }
            self?.assumeIsolated { $0.trackServicesUpdate() } // TODO: we can assume actor isolation! However, not stable and we are replacing that anyways!
        }
    }

    private func handleServicesChange() {
        service = peripheral.assumeIsolated { $0.getService(id: serviceId) }
    }
}
