//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


@Observable
public class GATTCharacteristic {
    // TODO: service back pointer?
    let underlyingCharacteristic: CBCharacteristic

    public private(set) weak var service: GATTService?

    /// Whether the characteristic is currently notifying or not.
    public private(set) var isNotifying: Bool
    /// The value of the characteristic.
    public private(set) var value: Data?
    /// A list of the descriptors that have so far been discovered in this characteristic.
    public private(set) var descriptors: [CBDescriptor]? // TODO: map this to a type!

    public var uuid: CBUUID {
        underlyingCharacteristic.uuid
    }

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


    func update() {
        if underlyingCharacteristic.isNotifying != isNotifying {
            isNotifying = underlyingCharacteristic.isNotifying
        }
        if underlyingCharacteristic.value != value {
            value = underlyingCharacteristic.value
        }
        // TODO: think about descriptors
    }
}


extension GATTCharacteristic: CustomDebugStringConvertible {
    public var debugDescription: String {
        underlyingCharacteristic.debugIdentifier
    }
}
