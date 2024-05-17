//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID
import SpeziBluetooth


/// Bluetooth Current Time Service implementation.
///
/// This class partially implements the Bluetooth [Current Time Service 1.1](https://www.bluetooth.com/specifications/specs/current-time-service-1-1).
/// - Note: The Local Time Information and Reference Time Information characteristics are currently not implemented.
///     Both are optional to implement for peripherals.
public final class CurrentTimeService: BluetoothService, @unchecked Sendable {
    public static let id = CBUUID(string: "1805")


    /// The current time and reason for adjustment.
    ///
    /// The characteristic can be used to read or modify the current time of the peripheral.
    ///
    /// - Note: This characteristic is required for this service. It is required to have
    ///     _read_ and _notify_ properties and optionally _write_ property.
    ///
    /// During read and notify operations, the characteristics values are derived from the local date and time
    /// of the peripheral. During a write operation, the peripheral may uses the information to set its local time.
    ///
    /// - Note: The peripheral may choose to ignore fields of the current time during writes. In this case
    ///     it may return the error code 0x80 _Data field ignored_.
    @Characteristic(id: "2A2B", notify: true)
    public var currentTime: CurrentTime?


    public init() {}
}
