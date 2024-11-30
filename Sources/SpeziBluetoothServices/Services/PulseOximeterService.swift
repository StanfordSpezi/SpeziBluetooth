//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore
import SpeziBluetooth
import SpeziNumerics


/// Bluetooth Pulse Oximeter (PLX) Service implementation.
///
/// This type implements the Bluetooth [Pulse Oximeter Service 1.0.1](https://www.bluetooth.com/specifications/specs/plxs-html/).
public struct PulseOximeterService: BluetoothService, Sendable {
    public static let id: BTUUID = "1822"
    
    /// Defines the features suppored by the pulse oximeter.
    ///
    /// - Note: This characteristic is required and read-only.
    @Characteristic(id: "2A60")
    public var features: PLXFeatures?
    
    /// Read a (usually one-time) spot-check measurement.
    @Characteristic(id: "2A5E", notify: true, autoRead: false)
    public var spotCheckMeasurement: PLXSpotCheckMeasurement?

    /// Receive continuous PLX (i.e., bood oxygen saturation and pulse rate) measurements.
    @Characteristic(id: "2A5F", notify: true, autoRead: false)
    public var continuousMeasurement: PLXContinuousMeasurement?
    
    /// Create a new Pulse Oximeter Service.
    public init() {}
}
