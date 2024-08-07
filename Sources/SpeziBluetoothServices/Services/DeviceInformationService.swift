//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziBluetooth


/// Bluetooth Device Information Service implementation.
///
/// This class implements the Bluetooth [Device Information Service 1.1.](https://www.bluetooth.com/specifications/specs/device-information-service-1-1/).
/// All characteristics are read-only and optional to implement.
/// It is possible that none are implemented at all.
/// For more information refer to the specification.
public struct DeviceInformationService: BluetoothService, Sendable {
    public static let id: BTUUID = "180A"

    /// The manufacturer name string.
    @Characteristic(id: "2A29")
    public var manufacturerName: String?
    /// The model number string.
    @Characteristic(id: "2A24")
    public var modelNumber: String?
    /// The serial number string.
    @Characteristic(id: "2A25")
    public var serialNumber: String?

    /// The hardware revision string.
    @Characteristic(id: "2A27")
    public var hardwareRevision: String?
    /// The firmware revision string.
    @Characteristic(id: "2A26")
    public var firmwareRevision: String?
    /// The software revision string.
    @Characteristic(id: "2A28")
    public var softwareRevision: String?

    /// Represents the extended unique identifier (EUI) of the system.
    ///
    /// This 64-bit structure is an EUI-64 which consists of an Organizationally Unique Identifier (OUI)
    /// concatenated with a manufacturer-defined identifier. The OUI is issued by the IEEE Registration Authority.
    @Characteristic(id: "2A23")
    public var systemID: UInt64?
    /// Represents regulatory and certification information for the product in a list defined in IEEE 11073-20601.
    ///
    /// The content of this characteristic is determined by the authorizing organization that provides certifications.
    @Characteristic(id: "2A2A")
    public var regulatoryCertificationDataList: Data?
    /// A set of values that shall be used to create a device ID value that is unique for this device.
    ///
    /// Included in the characteristic are a Vendor ID source field, a Vendor ID field, a Product ID field, and a Product Version field.
    /// These values are used to identify all devices of a given type/model/version using numbers.
    @Characteristic(id: "2A50")
    public var pnpID: PnPID?


    public init() {}
}
