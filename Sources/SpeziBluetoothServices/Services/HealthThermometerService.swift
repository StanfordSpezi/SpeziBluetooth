//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth


/// Bluetooth Health Thermometer Service implementation.
///
/// This class implements the Bluetooth [Health Thermometer Service 1.0](https://www.bluetooth.com/specifications/specs/health-thermometer-service-1-0).
public struct HealthThermometerService: BluetoothService, Sendable {
    public static let id: BTUUID = "1809"

    /// Receive temperature measurements.
    ///
    /// - Note: This characteristic is required and indicate-only.
    @Characteristic public var temperatureMeasurement: TemperatureMeasurement?
    /// The body location of the temperature measurement.
    ///
    /// Either use this static property or dynamically set it within ``TemperatureMeasurement/temperatureType``.
    /// Don't use both. Either of one is required.
    ///
    /// - Note: This characteristic is optional and read-only.
    @Characteristic(id: "2A1D")
    public var temperatureType: TemperatureType?
    /// Receive intermediate temperature values to a device for display purposes while a measurement is in progress.
    ///
    /// - Note: This characteristic is optional and notify-only.
    @Characteristic(id: "2A1E", notify: true)
    public var intermediateTemperature: TemperatureMeasurement?
    /// The measurement interval between two measurements.
    ///
    /// Describes the measurements of ``temperatureMeasurement``.
    ///
    /// - Note: This characteristic is optional and read-only.
    ///     Optionally it might indicate and writeable.
    @Characteristic(id: "2A21")
    public var measurementInterval: MeasurementInterval?


    /// Initialize a new Health Thermometer Service.
    /// - Parameter autoRead: Automatically read the initial value of the measurement characteristic.
    public init(autoRead: Bool = false) {
        _temperatureMeasurement = Characteristic(id: "2A1C", notify: true, autoRead: autoRead)
    }
}
