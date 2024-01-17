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
    /// There is an ongoing write access for that characteristic.
    case concurrentWriteCharacteristicAccess
    /// Could not decode the ByteBuffer into the provided ByteDecodable.
    case incompatibleDataFormat

    
    /// Provides a human-readable description of the error.
    public var description: String {
        errorDescription ?? "BluetoothError: \(rawValue)"
    }
    
    /// Provides a detailed description of the error.
    public var errorDescription: String? {
        switch self {
        case .concurrentWriteCharacteristicAccess:
            "Concurrent Characteristic Access" // TODO: translate error!
        case .incompatibleDataFormat:
            "Incompatible Data Format"
        }
    }
}
