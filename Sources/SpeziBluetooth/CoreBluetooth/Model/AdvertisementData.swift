//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// All advertised information of a peripheral.
public struct AdvertisementData {
    /// The raw advertisement data dictionary provided by CoreBluetooth.
    public let rawAdvertisementData: [String: Any]

    /// The local name of a peripheral.
    public var localName: String? {
        rawAdvertisementData[CBAdvertisementDataLocalNameKey] as? String
    }

    /// The manufacturer data of a peripheral.
    public var manufacturerData: Data? {
        rawAdvertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    }

    /// Service-specific advertisement data.
    ///
    /// The keys are CBService UUIDs. The values are Data objects, representing service-specific data.
    public var serviceData: [CBUUID: Data]? { // swiftlint:disable:this discouraged_optional_collection
        rawAdvertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
    }

    /// The advertised service UUIDs.
    public var serviceUUIDs: [CBUUID]? { // swiftlint:disable:this discouraged_optional_collection
        rawAdvertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }

    /// An array of one or more CBUUID objects, representing CBService UUIDs that were found in the “overflow”
    /// area of the advertisement data.
    public var overflowServiceUUIDs: [CBUUID]? { // swiftlint:disable:this discouraged_optional_collection
        rawAdvertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
    }

    /// The transmit power of a peripheral.
    ///
    /// This key and value are available if the broadcaster (peripheral) provides its Tx power level in its advertising packet.
    /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
    public var txPowerLevel: NSNumber? {
        rawAdvertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
    }

    /// Determine if the advertising event type is connectable.
    public var isConnectable: Bool? { // swiftlint:disable:this discouraged_optional_boolean
        rawAdvertisementData[CBAdvertisementDataIsConnectable] as? Bool // bridge cast
    }

    /// An array solicited CBService UUIDs.
    public var solicitedServiceUUIDs: [CBUUID]? { // swiftlint:disable:this discouraged_optional_collection
        rawAdvertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
    }


    /// Creates advertisement data based on CoreBluetooth's dictionary.
    /// - Parameter advertisementData: Core Bluetooth's advertisement data
    public init(_ advertisementData: [String: Any]) {
        self.rawAdvertisementData = advertisementData
    }
}
