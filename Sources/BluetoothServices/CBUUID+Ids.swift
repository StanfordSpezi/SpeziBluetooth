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
    public static let deviceInformationService = CBUUID(string: "180A")

    public static let manufacturerNameStringCharacteristic = CBUUID(string: "2A29")
    public static let modelNumberStringCharacteristic = CBUUID(string: "2A24")
    public static let serialNumberStringCharacteristic = CBUUID(string: "2A25")

    public static let hardwareRevisionStringCharacteristic = CBUUID(string: "2A27")
    public static let firmwareRevisionStringCharacteristic = CBUUID(string: "2A26")
    public static let softwareRevisionStringCharacteristic = CBUUID(string: "2A28")
    
    public static let systemIdCharacteristic = CBUUID(string: "2A23")
    public static let regulatoryCertificationDataListCharacteristic = CBUUID(string: "2A2A")
    public static let pnpIdCharacteristic = CBUUID(string: "2A50")
}


// MARK: Health Thermometer Service
extension CBUUID {
    public static let healthThermometerService = CBUUID(string: "1809")

    public static let temperatureMeasurementCharacteristic = CBUUID(string: "2A1C")
    public static let temperatureTypeCharacteristic = CBUUID(string: "2A1D")
    public static let intermediateTemperatureCharacteristic = CBUUID(string: "2A1E")
    public static let measurementIntervalCharacteristic = CBUUID(string: "2A21")
}
