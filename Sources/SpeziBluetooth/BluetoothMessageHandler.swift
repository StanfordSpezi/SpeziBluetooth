//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import CoreBluetooth
import Foundation


/// Protocol defining methods for handling Bluetooth messages.
public protocol BluetoothMessageHandler: AnyObject {
    /// Handles the receipt of Bluetooth data from a specified service and characteristic.
    ///
    /// - Parameters:
    ///   - data: The received Bluetooth data.
    ///   - service: The UUID of the Bluetooth service from which the data was received.
    ///   - characteristic: The UUID of the characteristic from which the data was received.
    func recieve(_ data: Data, service: CBUUID, characteristic: CBUUID) async
}
