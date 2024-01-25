//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


/// A Bluetooth service of a device.
///
/// ## Topics
///
/// ### Instance Properties
/// - ``uuid``
/// - ``isPrimary``
/// - ``characteristics``
@Observable
public class GATTService {
    let underlyingService: CBService

    /// The Bluetooth UUID of the service.
    public var uuid: CBUUID {
        underlyingService.uuid
    }

    /// The type of the service (primary or secondary).
    public var isPrimary: Bool {
        underlyingService.isPrimary
    }

    /// A list of characteristics that have been discovered in this service.
    public private(set) var characteristics: [GATTCharacteristic]


    init(service: CBService) {
        self.underlyingService = service
        self.characteristics = []

        didDiscoverCharacteristics()
    }


    /// Retrieve a characteristic.
    /// - Parameter id: The Bluetooth characteristic id.
    /// - Returns: The characteristic instance if present.
    public func getCharacteristic(id: CBUUID) -> GATTCharacteristic? {
        characteristics.first { characteristics in
            characteristics.uuid == id
        }
    }

    func didDiscoverCharacteristics() {
        guard let serviceCharacteristics = underlyingService.characteristics else {
            characteristics.removeAll()
            return
        }

        characteristics = serviceCharacteristics.map { characteristic in
            GATTCharacteristic(characteristic: characteristic, service: self)
        }
    }
}


extension GATTService: Hashable {
    public static func == (lhs: GATTService, rhs: GATTService) -> Bool {
        lhs.underlyingService == rhs.underlyingService
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(underlyingService)
    }
}
