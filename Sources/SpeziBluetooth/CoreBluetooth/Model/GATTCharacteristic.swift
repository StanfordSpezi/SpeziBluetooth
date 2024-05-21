//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import CoreBluetooth
import Foundation


struct CBCharacteristicCapture {
    let isNotifying: Bool
    let value: Data?
    let descriptors: [CBDescriptor]? // swiftlint:disable:this discouraged_optional_collection

    init(from characteristic: CBCharacteristic) {
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.descriptors = characteristic.descriptors
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
    public var uuid: CBUUID {
        underlyingCharacteristic.uuid
    }

    /// The properties of the characteristic.
    public var properties: CBCharacteristicProperties {
        underlyingCharacteristic.properties
    }

    init(characteristic: CBCharacteristic, service: GATTService) {
        self.underlyingCharacteristic = characteristic
        self.service = service
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.descriptors = characteristic.descriptors
    }


    func synchronizeModel(capture: CBCharacteristicCapture) { // always called from the Bluetooth thread
        if capture.isNotifying != isNotifying {
            isNotifying = capture.isNotifying
        }
        if capture.value != value {
            value = capture.value
        }
        if capture.descriptors != descriptors {
            descriptors = capture.descriptors
        }
    }
}


extension GATTCharacteristic: @unchecked Sendable {}


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
