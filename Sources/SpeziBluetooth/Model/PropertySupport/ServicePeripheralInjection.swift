//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


@Observable
class ServicePeripheralInjection {
    private let peripheral: BluetoothPeripheral
    private let serviceId: CBUUID

    private(set) weak var service: GATTService?


    init(peripheral: BluetoothPeripheral, serviceId: CBUUID, service: GATTService?) {
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.service = service
    }

    func setup() {
        trackServicesUpdate()
    }

    private func trackServicesUpdate() {
        withObservationTracking {
            _ = peripheral.getService(id: serviceId)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleServicesChange()
            }
            self?.trackServicesUpdate()
        }
    }

    @MainActor
    private func handleServicesChange() {
        service = peripheral.getService(id: serviceId)
    }
}
