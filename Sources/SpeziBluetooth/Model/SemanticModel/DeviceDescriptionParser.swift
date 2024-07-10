//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


private struct CharacteristicsBuilder: ServiceVisitor {
    var characteristics: Set<CharacteristicDescription> = []

    mutating func visit<Value>(_ characteristic: Characteristic<Value>) {
        characteristics.insert(characteristic.description)
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


extension BluetoothDevice {
    @SpeziBluetooth
    static func parseDeviceDescription() -> DeviceDescription {
        let device = Self()

        var builder = ServiceDescriptionBuilder()
        device.accept(&builder)
        return DeviceDescription(services: builder.configurations)
    }
}


extension DeviceDiscoveryDescriptor {
    @SpeziBluetooth
    func parseDiscoveryDescription() -> DiscoveryDescription {
        let deviceDescription = deviceType.parseDeviceDescription()
        return DiscoveryDescription(discoverBy: discoveryCriteria, device: deviceDescription)
    }
}


extension Set where Element == DeviceDiscoveryDescriptor {
    var deviceTypes: [any BluetoothDevice.Type] {
        map { configuration in
            configuration.deviceType
        }
    }

    @SpeziBluetooth
    func parseDiscoveryDescription() -> Set<DiscoveryDescription> {
        Set<DiscoveryDescription>(map { $0.parseDiscoveryDescription() })
    }
}
