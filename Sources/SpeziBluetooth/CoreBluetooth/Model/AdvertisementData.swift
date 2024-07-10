//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// All advertised information of a peripheral.
public struct AdvertisementData { // TODO: make it a struct that stores all elements plainly
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
    public var serviceData: [BTUUID: Data]? { // swiftlint:disable:this discouraged_optional_collection
        (rawAdvertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data])?
            .reduce(into: [:]) { partialResult, entry in
                partialResult[BTUUID(from: entry.key)] = entry.value
            }
    }

    /// The advertised service UUIDs.
    public var serviceUUIDs: [BTUUID]? { // swiftlint:disable:this discouraged_optional_collection
        (rawAdvertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map { BTUUID(from: $0) }
    }

    /// An array of one or more CBUUID objects, representing CBService UUIDs that were found in the “overflow”
    /// area of the advertisement data.
    public var overflowServiceUUIDs: [BTUUID]? { // swiftlint:disable:this discouraged_optional_collection
        (rawAdvertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID])?
            .map { BTUUID(from: $0) }
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
    public var solicitedServiceUUIDs: [BTUUID]? { // swiftlint:disable:this discouraged_optional_collection
        (rawAdvertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID])?
            .map { BTUUID(data: $0.data) }
    }


    /// Creates advertisement data based on CoreBluetooth's dictionary.
    /// - Parameter advertisementData: Core Bluetooth's advertisement data
    public init(_ advertisementData: [String: Any]) { // TODO: we can ignore Sendable warning, if we avoid exposing Any to the public?
        self.rawAdvertisementData = advertisementData
    }
}


extension AdvertisementData: Sendable {}
