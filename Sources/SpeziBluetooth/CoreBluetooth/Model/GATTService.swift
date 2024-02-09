//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation

struct ServiceChangeProtocol {
    let removedCharacteristics: Set<CBUUID>
    let updatedCharacteristics: [GATTCharacteristic]
}


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
    /// The stored characteristics, indexed by their uuid.
    private var _characteristics: [CBUUID: GATTCharacteristic]

    /// The Bluetooth UUID of the service.
    public var uuid: CBUUID {
        underlyingService.uuid
    }

    /// The type of the service (primary or secondary).
    public var isPrimary: Bool {
        underlyingService.isPrimary
    }

    /// A list of characteristics that have been discovered in this service.
    public var characteristics: [GATTCharacteristic] {
        Array(_characteristics.values)
    }


    init(service: CBService) {
        self.underlyingService = service
        self._characteristics = [:]
        self._characteristics = service.characteristics?.reduce(into: [:], { result, characteristic in
            result[characteristic.uuid] = GATTCharacteristic(characteristic: characteristic, service: self)
        }) ?? [:]
    }


    /// Retrieve a characteristic.
    /// - Parameter id: The Bluetooth characteristic id.
    /// - Returns: The characteristic instance if present.
    public func getCharacteristic(id: CBUUID) -> GATTCharacteristic? {
        characteristics.first { characteristics in
            characteristics.uuid == id
        }
    }

    /// Signal from the BluetoothManager to update your stored representations.
    func synchronizeModel() -> ServiceChangeProtocol {
        var removedCharacteristics = Set(_characteristics.keys)
        var updatedCharacteristics: [GATTCharacteristic] = []

        for cbCharacteristic in underlyingService.characteristics ?? [] {
            let characteristic = _characteristics[cbCharacteristic.uuid]
            if characteristic != nil {
                // The characteristic is there. Mark it as not removed.
                removedCharacteristics.remove(cbCharacteristic.uuid)
            }


            // either the characteristic does not exists, or the underlying reference changed
            if characteristic == nil || characteristic?.underlyingCharacteristic !== cbCharacteristic {
                // create/replace it
                let characteristic = GATTCharacteristic(characteristic: cbCharacteristic, service: self)
                updatedCharacteristics.append(characteristic)
                _characteristics[cbCharacteristic.uuid] = characteristic
            }
        }

        // remove all characteristics we haven't found in the
        for removedId in removedCharacteristics {
            _characteristics.removeValue(forKey: removedId)
        }

        return ServiceChangeProtocol(removedCharacteristics: removedCharacteristics, updatedCharacteristics: updatedCharacteristics)
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
