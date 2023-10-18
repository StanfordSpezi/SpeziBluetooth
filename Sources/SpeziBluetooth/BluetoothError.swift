//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import Foundation


/// Represents errors that can occur during Bluetooth operations.
public enum BluetoothError: String, Error, CustomStringConvertible, LocalizedError {
    /// Error indicating that the device is not connected.
    case notConnected
    /// Error indicating that the device connection has timed out.
    case deviceTimedOut
    
    
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
        }
    }
}
