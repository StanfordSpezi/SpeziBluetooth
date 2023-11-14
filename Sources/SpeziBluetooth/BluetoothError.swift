//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Represents errors that can occur during Bluetooth operations.
public enum BluetoothError: String, Error, CustomStringConvertible, LocalizedError {
    /// Error indicating that the device is not connected.
    case notConnected
    /// Error indicating that the device connection has timed out.
    case deviceTimedOut
    /// The characteristic you requested was not readable.
    case notAReadableCharacteristic
    
    
    /// Provides a human-readable description of the error.
    public var description: String {
        errorDescription ?? "BluetoothError: \(rawValue)"
    }
    
    /// Provides a detailed description of the error.
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            String(localized: "BLUETOOTH_ERROR_NOT_CONNECTED", bundle: .module)
        case .deviceTimedOut:
            String(localized: "BLUETOOTH_ERROR_DEVICE_TIME_OUT", bundle: .module)
        case .notAReadableCharacteristic:
            String(localized: "BLUETOOTH_ERROR_NOT_READABLE", bundle: .module)
        }
    }
}
