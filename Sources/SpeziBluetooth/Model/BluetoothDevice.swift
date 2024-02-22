//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation
import Spezi


/// A Bluetooth device implementation.
///
/// This protocol allows you to decoratively define your Bluetooth peripheral.
/// Use the ``Service`` property wrapper to declare all services of your device.
///
/// - Tip: You can use the ``DeviceState`` and ``DeviceAction`` property wrappers to retrieve device state
///     or interact with your Bluetooth device.
///
/// Below is a short code example of a device that implements a Device Information and Heart Rate service.
///
/// ```swift
/// class MyDevice: BluetoothDevice {
///     @Service var deviceInformation = DeviceInformationService()
///     @Service var heartRate = HeartRateService()
///
///     init() {}
/// }
/// ```
public protocol BluetoothDevice: AnyObject, EnvironmentAccessible {
    /// Initializes the Bluetooth Device.
    ///
    /// This initializer is called automatically when a peripheral of this type connects.
    ///
    /// The initializer is called on the Bluetooth Task.
    ///
    /// - Note: This initializer is also called upon configuration to inspect the device structure.
    ///     You might want to make sure to not perform any heavy processing within the initializer.
    init()
}
