//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID
import SpeziBluetooth


/// Bluetooth Weight Scale Service implementation.
///
/// This class implements the Bluetooth [Weight Scale Service 1.0](https://www.bluetooth.com/specifications/specs/weight-scale-service-1-0).
public final class WeightScaleService: BluetoothService, @unchecked Sendable {
    public static let id = CBUUID(string: "181D")

    /// Receive weight measurements.
    ///
    /// - Note: This characteristic is required and indicate-only.
    @Characteristic(id: "2A9D", notify: true, autoRead: false) // TODO: reenable this
    public var weightMeasurement: WeightMeasurement?

    /// Describe supported features and value resolutions of the weight scale.
    ///
    /// - Note: This characteristic is required and read-only.
    @Characteristic(id: "2A9E")
    public var features: WeightScaleFeature?


    public init() {}
}
