//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import CoreBluetooth


/// <#Description#>
public struct BluetoothService {
    /// <#Description#>
    public let serviceUUID: CBUUID
    /// <#Description#>
    public let characteristicUUIDs: [CBUUID]
    
    
    /// <#Description#>
    /// - Parameters:
    ///   - serviceUUID: <#serviceUUID description#>
    ///   - characteristicUUID: <#characteristicUUID description#>
    ///   - minimumRSSI: <#minimumRSSI description#>
    public init(serviceUUID: CBUUID, characteristicUUIDs: [CBUUID]) {
        self.serviceUUID = serviceUUID
        self.characteristicUUIDs = characteristicUUIDs
    }
}
