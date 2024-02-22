//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID


/// A Bluetooth service implementation.
///
/// This protocol allows you to decoratively define a service of a given Bluetooth peripheral.
/// Use the ``Characteristic`` property wrapper to declare all characteristics of your service.
///
/// - Tip: You may also use the ``DeviceState`` and ``DeviceAction`` property wrappers within your service implementation
///     to interact with the Bluetooth device the service is used on.
///
/// Below is a short code example that implements some parts of the Device Information service.
///
/// ```swift
/// class DeviceInformationService: BluetoothService {
///    static let id = CBUUID(string: "180A")
///
///     @Characteristic(id: "2A29")
///     var manufacturer: String?
///     @Characteristic(id: "2A26")
///     var firmwareRevision: String?
/// }
/// ```
public protocol BluetoothService: AnyObject {
    /// The Bluetooth service id.
    static var id: CBUUID { get }
}
