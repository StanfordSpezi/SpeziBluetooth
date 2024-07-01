//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID
import SpeziBluetooth


/// Bluetooth Battery Service.
///
/// This class partially implements the Bluetooth [Battery Service 1.1](https://www.bluetooth.com/specifications/specs/battery-service).
/// - Note: The current implementation only implements mandatory characteristics.
public final class BatteryService: BluetoothService, @unchecked Sendable {
    public static var id: CBUUID {
        CBUUID(string: "180F")
    }


    /// Battery Level in percent.
    ///
    /// Battery Level in percent (range 0 to 100).
    /// 100 represents fully charged, 0 represents fully discharged.
    /// All other values are reserved.
    @Characteristic(id: "2A19", notify: true)
    public var batteryLevel: UInt8?


    public init() {}
}
