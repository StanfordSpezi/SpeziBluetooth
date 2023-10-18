//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import CoreBluetooth
import Foundation


/// <#Description#>
public protocol BluetoothMessageHandler: AnyObject {
    /// <#Description#>
    /// - Parameters:
    ///   - data: <#data description#>
    ///   - service: <#service description#>
    ///   - characteristic: <#characteristic description#>
    func recieve(_ data: Data, service: CBUUID, characteristic: CBUUID) async
}
