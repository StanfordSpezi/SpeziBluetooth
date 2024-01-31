//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID
import Foundation
import SpeziBluetooth


/// Bluetooth Device Information Service implementation.
///
/// This class implements the Bluetooth [Device Information Service 1.1.](https://www.bluetooth.com/specifications/specs/device-information-service-1-1/).
/// All characteristics are read-only and optional to implement.
/// It is possible that none are implemented at all.
/// For more information refer to the specification.
public class DeviceInformationService: BluetoothService {
    public static let id: CBUUID = .deviceInformationService

    /// The manufacturer name string.
    @Characteristic(id: .manufacturerNameStringCharacteristic)
    public var manufacturerName: String?
    /// The model number string.
    @Characteristic(id: .modelNumberStringCharacteristic)
    public var modelNumber: String?
    /// The serial number string.
    @Characteristic(id: .serialNumberStringCharacteristic)
    public var serialNumber: String?

    /// The hardware revision string.
    @Characteristic(id: .hardwareRevisionStringCharacteristic)
    public var hardwareRevision: String?
    /// The firmware revision string.
    @Characteristic(id: .firmwareRevisionStringCharacteristic)
    public var firmwareRevision: String?
    /// The software revision string.
    @Characteristic(id: .softwareRevisionStringCharacteristic)
    public var softwareRevision: String?

    /// Represents the extended unique identifier (EUI) of the system.
    ///
    /// This 64-bit structure is an EUI-64 which consists of an Organizationally Unique Identifier (OUI)
    /// concatenated with a manufacturer-defined identifier. The OUI is issued by the IEEE Registration Authority.
    @Characteristic(id: .systemIdCharacteristic)
    public var systemID: UInt64?
    /// Represents regulatory and certification information for the product in a list defined in IEEE 11073-20601.
    ///
    /// The content of this characteristic is determined by the authorizing organization that provides certifications.
    @Characteristic(id: .regulatoryCertificationDataListCharacteristic)
    public var regulatoryCertificationDataList: Data?
    /// A set of values that shall be used to create a device ID value that is unique for this device.
    ///
    /// Included in the characteristic are a Vendor ID source field, a Vendor ID field, a Product ID field, and a Product Version field.
    /// These values are used to identify all devices of a given type/model/version using numbers.
    @Characteristic(id: .pnpIdCharacteristic)
    public var pnpID: PnPID?


    public init() {}


    /// Queries all present device information.
    public func retrieveDeviceInformation() async throws {
        if $manufacturerName.isPresent {
            try await self.$manufacturerName.read()
        }
        if $modelNumber.isPresent {
            try await self.$modelNumber.read()
        }
        if $serialNumber.isPresent {
            try await self.$serialNumber.read()
        }

        if $hardwareRevision.isPresent {
            try await self.$hardwareRevision.read()
        }
        if $firmwareRevision.isPresent {
            try await self.$firmwareRevision.read()
        }
        if $softwareRevision.isPresent {
            try await self.$softwareRevision.read()
        }

        if $systemID.isPresent {
            try await self.$systemID.read()
        }
        if $regulatoryCertificationDataList.isPresent {
            try await self.$regulatoryCertificationDataList.read()
        }
        if $pnpID.isPresent {
            try await self.$pnpID.read()
        }
    }
}
