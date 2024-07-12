//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


struct GATTCharacteristicCapture: Sendable {
    let isNotifying: Bool
    let value: Data?
    let properties: CBCharacteristicProperties
    let descriptors: CBInstance<[CBDescriptor]>?

    init(from characteristic: CBCharacteristic) {
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.properties = characteristic.properties
        self.descriptors = characteristic.descriptors.map { CBInstance(instantiatedOnDispatchQueue: $0) }
    }

    @SpeziBluetooth
    fileprivate init(from characteristic: borrowing GATTCharacteristic) {
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.properties = characteristic.properties
        self.descriptors = characteristic.descriptors.map { CBInstance(instantiatedOnDispatchQueue: $0) }
    }
}


/// A Bluetooth characteristic of a service.
///
/// ## Topics
///
/// ### Instance Properties
/// - ``uuid``
/// - ``value``
/// - ``isNotifying``
/// - ``properties``
/// - ``descriptors``
/// - ``service``
@Observable
public final class GATTCharacteristic {
    let underlyingCharacteristic: CBCharacteristic

    /// The associated service if still available.
    public private(set) weak var service: GATTService?

    /// Whether the characteristic is currently notifying or not.
    public private(set) var isNotifying: Bool
    /// The value of the characteristic.
    public private(set) var value: Data?
    /// A list of the descriptors that have so far been discovered in this characteristic.
    public private(set) var descriptors: [CBDescriptor]? // swiftlint:disable:this discouraged_optional_collection

    /// The Bluetooth UUID of the characteristic.
    public var uuid: BTUUID {
        BTUUID(data: underlyingCharacteristic.uuid.data)
    }

    /// The properties of the characteristic.
    public var properties: CBCharacteristicProperties {
        underlyingCharacteristic.properties
    }

    @SpeziBluetooth var captured: GATTCharacteristicCapture {
        GATTCharacteristicCapture(from: self)
    }

    init(characteristic: CBCharacteristic, service: GATTService) {
        self.underlyingCharacteristic = characteristic
        self.service = service
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.descriptors = characteristic.descriptors
    }


    @SpeziBluetooth
    func synchronizeModel(capture: GATTCharacteristicCapture) {
        if capture.isNotifying != isNotifying {
            isNotifying = capture.isNotifying
        }
        if capture.value != value {
            value = capture.value
        }
        if capture.descriptors?.cbObject != descriptors {
            descriptors = capture.descriptors?.cbObject
        }
    }
}


extension GATTCharacteristic {}


extension GATTCharacteristic: CustomDebugStringConvertible {
    public var debugDescription: String {
        underlyingCharacteristic.debugIdentifier
    }
}


extension GATTCharacteristic: Hashable {
    public static func == (lhs: GATTCharacteristic, rhs: GATTCharacteristic) -> Bool {
        lhs.underlyingCharacteristic == rhs.underlyingCharacteristic
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(underlyingCharacteristic)
    }
}
