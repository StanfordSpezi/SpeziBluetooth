//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


// MARK: Device Information Service
extension CBUUID {
    /// The Device Information Service UUID.
    public static let deviceInformationService = CBUUID(string: "180A")

    /// The Manufacturer Name String Characteristic UUID.
    public static let manufacturerNameStringCharacteristic = CBUUID(string: "2A29")
    /// The Model Number String Characteristic UUID.
    public static let modelNumberStringCharacteristic = CBUUID(string: "2A24")
    /// The Serial Number String Characteristic UUID.
    public static let serialNumberStringCharacteristic = CBUUID(string: "2A25")

    /// The Hardware Revision String Characteristic UUID.
    public static let hardwareRevisionStringCharacteristic = CBUUID(string: "2A27")
    /// The Firmware Revision String Characteristic UUID.
    public static let firmwareRevisionStringCharacteristic = CBUUID(string: "2A26")
    /// The Software Revision String Characteristic UUID.
    public static let softwareRevisionStringCharacteristic = CBUUID(string: "2A28")

    /// The System ID Characteristic UUID.
    public static let systemIdCharacteristic = CBUUID(string: "2A23")
    /// The Regulatory Certification Data List Characteristic UUID.
    public static let regulatoryCertificationDataListCharacteristic = CBUUID(string: "2A2A")
    // swiftlint:disable:previous identifier_name
    /// The PnP ID Characteristic UUID.
    public static let pnpIdCharacteristic = CBUUID(string: "2A50")
}


// MARK: Health Thermometer Service
extension CBUUID {
    /// The Health Thermometer Service UUID.
    public static let healthThermometerService = CBUUID(string: "1809")

    /// The Temperature Measurement Characteristic UUID.
    public static let temperatureMeasurementCharacteristic = CBUUID(string: "2A1C")
    /// The Temperature Type Characteristic UUID.
    public static let temperatureTypeCharacteristic = CBUUID(string: "2A1D")
    /// The Intermediate Temperature Characteristic UUID.
    public static let intermediateTemperatureCharacteristic = CBUUID(string: "2A1E")
    /// The Measurement Interval Characteristic UUID.
    public static let measurementIntervalCharacteristic = CBUUID(string: "2A21")
}
