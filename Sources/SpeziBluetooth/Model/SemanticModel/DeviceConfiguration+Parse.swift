//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


struct CharacteristicsBuilder: ServiceVisitor {
    var characteristics: [CBUUID] = [] // TODO: make this a set?

    mutating func visit<Value>(_ characteristic: Characteristic<Value>) {
        characteristics.append(characteristic.id)
    }
}


struct ServiceConfigurationBuilder: DeviceVisitor {
    var configurations: Set<ServiceConfiguration> = []

    mutating func visit<S: BluetoothService>(_ service: Service<S>) {
        var visitor = CharacteristicsBuilder()
        service.wrappedValue.accept(&visitor)

        let configuration = ServiceConfiguration(serviceId: service.id, characteristics: visitor.characteristics)
        configurations.insert(configuration)
    }
}


extension DeviceConfiguration {
    func parseDiscoveryConfiguration() -> DiscoveryConfiguration {
        let device = anyDeviceType.init()

        var builder = ServiceConfigurationBuilder()
        device.accept(&builder)
        return DiscoveryConfiguration(criteria: discoveryCriteria, services: builder.configurations)
    }
}
