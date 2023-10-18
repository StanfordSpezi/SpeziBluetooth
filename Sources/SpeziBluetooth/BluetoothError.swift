//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import Foundation


public enum BluetoothError: String, Error, CustomStringConvertible, LocalizedError {
    case notConnected
    case deviceTimedOut
    
    
    public var description: String {
        errorDescription ?? "BluetoothError: \(rawValue)"
    }
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "The device is not connected. Please ensure that the device is powered on or try to restart the device."
        case .deviceTimedOut:
            return "The device no longer sends new measurement values. The connection seemed to have timed out."
        }
    }
}
