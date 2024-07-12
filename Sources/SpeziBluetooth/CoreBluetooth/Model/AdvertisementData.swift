//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// Advertisement information of a peripheral.
public struct AdvertisementData {
    /// The local name of a peripheral.
    public let localName: String?
    /// The manufacturer data of a peripheral.
    public let manufacturerData: Data?
    /// Service-specific advertisement data.
    ///
    /// The keys are CBService UUIDs. The values are Data objects, representing service-specific data.
    public let serviceData: [BTUUID: Data]? // swiftlint:disable:this discouraged_optional_collection
    /// The advertised service UUIDs.
    public let serviceUUIDs: [BTUUID]? // swiftlint:disable:this discouraged_optional_collection
    /// An array of one or additional service UUIDs, representing CBService UUIDs that were found in the “overflow”
    /// area of the advertisement data.
    public let overflowServiceUUIDs: [BTUUID]? // swiftlint:disable:this discouraged_optional_collection

    /// The transmit power of a peripheral.
    ///
    /// This key and value are available if the broadcaster (peripheral) provides its Tx power level in its advertising packet.
    /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
    public let txPowerLevel: NSNumber?
    /// Determine if the advertising event type is connectable.
    public let isConnectable: Bool? // swiftlint:disable:this discouraged_optional_boolean
    /// An array solicited CBService UUIDs.
    public let solicitedServiceUUIDs: [BTUUID]? // swiftlint:disable:this discouraged_optional_collection


    /// Create new advertisement data.
    ///
    /// This might be helpful to inject advertisement data into a peripheral for testing purposes.
    ///
    /// - Parameters:
    ///   - localName: The local name of a peripheral.
    ///   - manufacturerData: The manufacturer data of a peripheral.
    ///   - serviceData: Service-specific advertisement data.
    ///   - serviceUUIDs: The advertised service UUIDs.
    ///   - overflowServiceUUIDs: Advertised service UUIDs found in the "overflow" area of the advertisement data.
    ///   - txPowerLevel:
    ///   - isConnectable:
    ///   - solicitedServiceUUIDs:
    public init(
        localName: String? = nil,
        manufacturerData: Data? = nil,
        serviceData: [BTUUID: Data]? = nil, // swiftlint:disable:this discouraged_optional_collection
        serviceUUIDs: [BTUUID]? = nil, // swiftlint:disable:this discouraged_optional_collection
        overflowServiceUUIDs: [BTUUID]? = nil, // swiftlint:disable:this discouraged_optional_collection
        txPowerLevel: NSNumber? = nil,
        isConnectable: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
        solicitedServiceUUIDs: [BTUUID]? = nil // swiftlint:disable:this discouraged_optional_collection
    ) {
        self.localName = localName
        self.manufacturerData = manufacturerData
        self.serviceData = serviceData
        self.serviceUUIDs = serviceUUIDs
        self.overflowServiceUUIDs = overflowServiceUUIDs
        self.txPowerLevel = txPowerLevel
        self.isConnectable = isConnectable
        self.solicitedServiceUUIDs = solicitedServiceUUIDs
    }
}


extension AdvertisementData {
    /// Creates advertisement data based on CoreBluetooth's dictionary.
    /// - Parameter advertisementData: Core Bluetooth's advertisement data
    init(_ advertisementData: [String: Any]) {
        self.init(
            localName: advertisementData[CBAdvertisementDataLocalNameKey] as? String,
            manufacturerData: advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
            serviceData: (advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data])?
                .reduce(into: [:]) { partialResult, entry in
                    partialResult[BTUUID(from: entry.key)] = entry.value
                },
            serviceUUIDs: (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
                .map { BTUUID(from: $0) },
            overflowServiceUUIDs: (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID])?
                .map { BTUUID(from: $0) },
            txPowerLevel: advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber,
            isConnectable: advertisementData[CBAdvertisementDataIsConnectable] as? Bool, // bridge cast
            solicitedServiceUUIDs: (advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID])?
                .map { BTUUID(data: $0.data) }
        )
    }
}


extension AdvertisementData: Sendable, Hashable {}
