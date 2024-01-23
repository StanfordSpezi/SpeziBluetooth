//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices
import CoreBluetooth
import SpeziBluetooth


@main
class TestPeripheral: NSObject, CBPeripheralManagerDelegate {
    private let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth-peripheral", qos: .userInitiated)
    var peripheralManager: CBPeripheralManager!

    var healthThermometer: CBMutableService?

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: dispatchQueue)
    }

    static func main() {
        let peripheral = TestPeripheral()
        while true {}
    }

    func startAdvertising() {
        peripheralManager.removeAllServices() // TODO: required?

        let healthThermometer = CBMutableService(type: .healthThermometerService, primary: true)

        let temperatureMeasurement = CBMutableCharacteristic(
            type: .temperatureMeasurementCharacteristic,
            properties: [.indicate],
            value: nil, // TODO: how to do value!
            permissions: []
        )

        let temperatureType = CBMutableCharacteristic(
            type: .temperatureTypeCharacteristic,
            properties: [.read],
            value: TemperatureType.body.encode(),
            permissions: [.readable]
        )

        healthThermometer.characteristics = [temperatureMeasurement, temperatureType]
        self.healthThermometer = healthThermometer

        peripheralManager.add(healthThermometer)
    }

    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // TODO: logger!
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            // Handle other states if needed
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Error adding service \(service.uuid): \(error.localizedDescription)")
            return
        }

        if let healthThermometer {
            let advertisementData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [healthThermometer.uuid],
                CBAdvertisementDataLocalNameKey: "Test Thermometer"
            ]
            peripheralManager.startAdvertising(advertisementData)
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Error starting advertising: \(error.localizedDescription)")
        } else {
            print("Peripheral advertising started successfully!")
        }
    }
}
