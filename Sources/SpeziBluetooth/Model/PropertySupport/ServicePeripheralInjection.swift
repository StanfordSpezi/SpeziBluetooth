//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


actor ServicePeripheralInjection: BluetoothActor {
    let bluetoothQueue: DispatchSerialQueue

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

    nonisolated var unsafeService: GATTService? {
        _service.value
    }


    init(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: GATTService?) {
        self.bluetoothQueue = peripheral.bluetoothQueue
        self.peripheral = peripheral
        self.serviceId = serviceId
        self._service = WeakObservableBox(service)
    }

    func setup() {
        trackServicesUpdate()
    }

    private func trackServicesUpdate() {
        peripheral.assumeIsolated { peripheral in
            peripheral.onChange(of: \.services) { [weak self] services in
                guard let self = self,
                      let service = services?.first(where: { $0.uuid == self.serviceId }) else {
                    return
                }

                self.assumeIsolated { injection in
                    injection.trackServicesUpdate()
                    injection.service = service
                }
            }
        }
    }
}
