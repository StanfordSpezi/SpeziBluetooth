//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID
import SpeziBluetooth


/// Bluetooth Blood Pressure Service implementation.
///
/// This class partially implements the Bluetooth [Blood Pressure Service 1.1](https://www.bluetooth.com/specifications/specs/blood-pressure-service-1-1-1).
/// - Note: The Enhance Blood Pressure Service is currently not supported.
public final class BloodPressureService: BluetoothService, @unchecked Sendable {
    public static let id = CBUUID(string: "1810")

    /// Receive blood pressure measurements
    ///
    /// - Note: This characteristic is required and indicate-only.
    @Characteristic(id: "2A35", notify: true)
    public var bloodPressureMeasurement: BloodPressureMeasurement?

    /// Describe supported features of the blood pressure cuff.
    ///
    /// - Note: This characteristic is required and read-only (optionally supports indicate).
    @Characteristic(id: "2A49", notify: true)
    public var features: BloodPressureFeature?

    /// Receive intermdaite cuff pressure.
    ///
    /// - Note: This characteristic is optional and notify-only.
    @Characteristic(id: "2A36", notify: true)
    public var intermediateCuffPressure: IntermediateCuffPressure?


    public init() {}
}
