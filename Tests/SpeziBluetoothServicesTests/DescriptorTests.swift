#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit
#endif
import Foundation
import SpeziBluetooth
import SpeziBluetoothServices
import Testing


@Suite("Descriptor")
struct DescriptorTests {
    @Test("Name Criteria")
    func testNameCriteria() {
        let name: DeviceVariantCriteria = .nameSubstring("Hello")

        #expect(name.matches(name: "Hello ", advertisementData: .init()))
        #expect(!name.matches(name: "Other Device", advertisementData: .init()))
        #expect(name.matches(name: "Other Device", advertisementData: .init(localName: "Hello ")))
        #expect(!name.matches(name: "Hello ", advertisementData: .init(localName: "No Match")))
    }

    @Test("Manufacturer Criteria")
    func testManufacturerCriteria() {
        let manufacturer: DeviceVariantCriteria = .manufacturer(.init(0x01))

        #expect(manufacturer.matches(name: "Device", advertisementData: .init(manufacturerData: Data([0x01, 0x00]))))
        #expect(manufacturer.matches(name: "Device", advertisementData: .init(manufacturerData: Data([0x01, 0x00, 0x02]))))
        #expect(!manufacturer.matches(name: "Device", advertisementData: .init(manufacturerData: Data([0x02, 0x02, 0x02]))))

        let manufacturerData: DeviceVariantCriteria = .manufacturer(
            .init(rawValue: 0x01),
            manufacturerData: .init(data: Data([0xFF]), mask: Data([0b11001010]))
        )

        #expect(!manufacturerData.matches(name: "Device", advertisementData: .init(manufacturerData: Data([0x01, 0x00]))))
        #expect(!manufacturerData.matches(name: "Device", advertisementData: .init(manufacturerData: Data([0x01, 0x00, 0x02]))))
        #expect(!manufacturerData.matches(name: "Device", advertisementData: .init(
            manufacturerData: Data([0x02, 0x00, 0b11101110])
        )))
        #expect(manufacturerData.matches(name: "Device", advertisementData: .init(
            manufacturerData: Data([0x01, 0x00, 0b11101110])
        )))
    }

    @Test("Service Criteria")
    func testServiceCriteria() { // swiftlint:disable:this function_body_length
        let service: DeviceVariantCriteria = .service(BatteryService.self)

        #expect(service.matches(name: "Device", advertisementData: .init(serviceUUIDs: [
            BatteryService.id
        ])))

        #expect(service.matches(name: "Device", advertisementData: .init(overflowServiceUUIDs: [
            BatteryService.id
        ])))

        #expect(service.matches(name: "Device", advertisementData: .init(
            serviceUUIDs: [
                BatteryService.id
            ],
            overflowServiceUUIDs: [
                BatteryService.id
            ]
        )))

        #expect(service.matches(name: "Device", advertisementData: .init(
            overflowServiceUUIDs: [
                BatteryService.id
            ]
        )))

        #expect(service.matches(name: "Device", advertisementData: .init(
            serviceUUIDs: [
                DeviceInformationService.id
            ],
            overflowServiceUUIDs: [
                BatteryService.id
            ]
        )))

        #expect(service.matches(name: "Device", advertisementData: .init(
            serviceUUIDs: [
                BatteryService.id
            ],
            overflowServiceUUIDs: [
                DeviceInformationService.id
            ]
        )))

        #expect(!service.matches(name: "Device", advertisementData: .init(serviceUUIDs: [
            DeviceInformationService.id
        ])))

        let serviceData: DeviceVariantCriteria = .service(BatteryService.self, serviceData: .init(data: Data([0xFF]), mask: Data([0b11001010])))

        #expect(!serviceData.matches(name: "Device", advertisementData: .init(serviceUUIDs: [
            DeviceInformationService.id
        ])))

        #expect(!serviceData.matches(name: "Device", advertisementData: .init(serviceUUIDs: [
            BatteryService.id
        ])))

        #expect(serviceData.matches(name: "Device", advertisementData: .init(
            serviceData: [
                BatteryService.id: Data([0b11101110])
            ],
            serviceUUIDs: [
                BatteryService.id
            ]
        )))

        #expect(!serviceData.matches(name: "Device", advertisementData: .init(
            serviceData: [
                BatteryService.id: Data([0b01101110])
            ],
            serviceUUIDs: [
                BatteryService.id
            ]
        )))
    }

    @Test("Appearance")
    func testAppearance() {
        let appearance = Appearance(name: "Product A", icon: .system("sensor"))
        let deviceAppearance: DeviceAppearance = .appearance(appearance)

        #expect(deviceAppearance.appearance(where: { _ in false }) == (appearance, nil))
        #expect(deviceAppearance.deviceIcon(variantId: "id1") == .system("sensor"))
        #expect(deviceAppearance.deviceName(variantId: "id2") == "Product A")
    }

    @Test("Variant")
    func testVariant() {
        let appearance = Appearance(name: "Product A", icon: .system("sensor"))
        let deviceAppearance: DeviceAppearance = .variants(
            defaultAppearance: appearance,
            variants: [
                Variant(id: "id1", name: "Product A1", criteria: .service(BatteryService.self)),
                Variant(id: "id2", name: "Product A2", criteria: .service(DeviceInformationService.self))
            ]
        )

        #expect(deviceAppearance.deviceName(variantId: "id1") == "Product A1")
        #expect(deviceAppearance.deviceName(variantId: "id2") == "Product A2")
    }

#if canImport(AccessorySetupKit) && !os(macOS)
    @Test("DeviceVariantCriteria AccessorySetupKit")
    func testAccessorySetupKit() {
        let criteria = DeviceVariantCriteria(from: [
            .nameSubstring("Hello"),
            .service(BatteryService.self, serviceData: .init(data: Data([0xFF]), mask: Data([0b11001010]))),
            .manufacturer(.init(rawValue: 0x01), manufacturerData: .init(data: Data([0xFF]), mask: Data([0b11001010])))
        ])

        if #available(iOS 18.0, *) {
            let descriptor = ASDiscoveryDescriptor()
            criteria.apply(to: descriptor)

            #expect(criteria.matches(descriptor: descriptor))
        }
    }

    @Test("DiscoveryDescriptor AccessorySetupKit")
    func testAccessorySetupKit2() {
        if #available(iOS 18.0, *) {
            let criteria: DiscoveryCriteria = .accessory(
                advertising: BatteryService.self,
                serviceData: .init(data: Data([0xFF]), mask: Data([0b11001010])),
                manufacturer: .init(0x01),
                manufacturerData: .init(data: Data([0xFF]), mask: Data([0b11001010])),
                nameSubstring: "Device",
                range: .immediate,
                supportOptions: .bluetoothPairingLE
            )

            let descriptor = criteria.discoveryDescriptor

            #expect(criteria.matches(descriptor: descriptor))
        }
    }
#endif
}
