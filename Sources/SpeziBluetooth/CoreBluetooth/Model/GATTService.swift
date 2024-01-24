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
public class GATTService {
    let underlyingService: CBService

    // TODO: peripheral back pointer?
    public var uuid: CBUUID {
        underlyingService.uuid
    }

    public var isPrimary: Bool {
        underlyingService.isPrimary
    }

    public private(set) var characteristics: [GATTCharacteristic]?

    // TODO: support included services?

    init(service: CBService) {
        self.underlyingService = service
        updateCharacteristics() // TODO: set update!
    }

    public func getCharacteristic(id: CBUUID) -> GATTCharacteristic? {
        characteristics?.first { characteristics in
            characteristics.uuid == id
        }
    }

    func updateCharacteristics() {
        guard let serviceCharacteristics = underlyingService.characteristics else {
            characteristics = nil
            return
        }

        // TODO: check for differences!!!
        characteristics = serviceCharacteristics.map { characteristic in
            GATTCharacteristic(characteristic: characteristic, service: self)
        }
    }
}
