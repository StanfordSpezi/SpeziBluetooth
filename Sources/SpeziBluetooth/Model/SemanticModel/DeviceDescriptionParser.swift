//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

private struct CharacteristicsBuilder: ServiceVisitor {
    var characteristics: [CBUUID] = [] // TODO: make this a set?

    mutating func visit<Value>(_ characteristic: Characteristic<Value>) {
        characteristics.append(characteristic.id)
    }
}


private struct ServiceDescriptionBuilder: DeviceVisitor {
    var configurations: Set<ServiceDescription> = []

    mutating func visit<S: BluetoothService>(_ service: Service<S>) {
        var visitor = CharacteristicsBuilder()
        service.wrappedValue.accept(&visitor)

        let configuration = ServiceDescription(serviceId: service.id, characteristics: visitor.characteristics)
        configurations.insert(configuration)
    }
}


extension DiscoveryConfiguration {
    func parseDeviceDescription() -> DeviceDescription { // TODO: rethink layout!
        let device = anyDeviceType.init()

        var builder = ServiceDescriptionBuilder()
        device.accept(&builder)
        return DeviceDescription(discoverBy: discoveryCriteria, services: builder.configurations)
    }
}
