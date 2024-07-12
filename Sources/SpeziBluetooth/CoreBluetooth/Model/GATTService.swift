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
    let removedCharacteristics: Set<BTUUID>
    let updatedCharacteristics: [GATTCharacteristic]
}

struct GATTServiceCapture: Sendable {
    let isPrimary: Bool
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
public final class GATTService {
    let underlyingService: CBService
    /// The stored characteristics, indexed by their uuid.
    private var _characteristics: [BTUUID: GATTCharacteristic]

    /// The Bluetooth UUID of the service.
    public var uuid: BTUUID {
        BTUUID(data: underlyingService.uuid.data)
    }

    /// The type of the service (primary or secondary).
    public var isPrimary: Bool {
        underlyingService.isPrimary
    }

    /// A list of characteristics that have been discovered in this service.
    public var characteristics: [GATTCharacteristic] {
        Array(_characteristics.values)
    }

    @SpeziBluetooth var captured: GATTServiceCapture {
        GATTServiceCapture(isPrimary: isPrimary)
    }


    init(service: CBService) {
        self.underlyingService = service
        self._characteristics = [:]
        self._characteristics = service.characteristics?.reduce(into: [:], { result, characteristic in
            result[BTUUID(from: characteristic.uuid)] = GATTCharacteristic(characteristic: characteristic, service: self)
        }) ?? [:]
    }


    /// Retrieve a characteristic.
    /// - Parameter id: The Bluetooth characteristic id.
    /// - Returns: The characteristic instance if present.
    public func getCharacteristic(id: BTUUID) -> GATTCharacteristic? {
        characteristics.first { characteristics in
            characteristics.uuid == id
        }
    }

    /// Signal from the BluetoothManager to update your stored representations.
    @SpeziBluetooth
    func synchronizeModel() -> ServiceChangeProtocol {
        var removedCharacteristics = Set(_characteristics.keys)
        var updatedCharacteristics: [GATTCharacteristic] = []

        for cbCharacteristic in underlyingService.characteristics ?? [] {
            let characteristic = _characteristics[BTUUID(from: cbCharacteristic.uuid)]
            if characteristic != nil {
                // The characteristic is there. Mark it as not removed.
                removedCharacteristics.remove(BTUUID(from: cbCharacteristic.uuid))
            }


            // either the characteristic does not exists, or the underlying reference changed
            if characteristic == nil || characteristic?.underlyingCharacteristic !== cbCharacteristic {
                // create/replace it
                let characteristic = GATTCharacteristic(characteristic: cbCharacteristic, service: self)
                updatedCharacteristics.append(characteristic)
                _characteristics[BTUUID(from: cbCharacteristic.uuid)] = characteristic
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
