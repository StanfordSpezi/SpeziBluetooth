//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


public typealias BluetoothNotificationHandler = (_ data: Data, _ service: CBUUID, _ characteristic: CBUUID) async -> Void


/// Protocol defining methods for handling Bluetooth messages.
public protocol BluetoothNotificationHandler2: AnyObject {
    // TODO: notification handler!

    /// Handles the receipt of Bluetooth data from a specified service and characteristic.
    ///
    /// - Parameters:
    ///   - data: The received Bluetooth data.
    ///   - service: The UUID of the Bluetooth service from which the data was received.
    ///   - characteristic: The UUID of the characteristic from which the data was received.
    func notify(_ data: Data, service: CBUUID, characteristic: CBUUID) async
}
