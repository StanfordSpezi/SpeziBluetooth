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
    /// Could not decode the ByteBuffer into the provided ByteDecodable.
    case incompatibleDataFormat
    /// Thrown when accessing a ``Characteristic`` when the device is not connected yet.
    case notConnected // TODO: can we throw CBErrors? hwo do errors look? are thes CBErrors or NSErrors?

    
    /// Provides a human-readable description of the error.
    public var description: String {
        errorDescription ?? "BluetoothError: \(rawValue)"
    }

    // TODO error description and failure reason

    /// Provides a detailed description of the error.
    public var errorDescription: String? {
        switch self {
        case .incompatibleDataFormat:
            "Incompatible Data Format"
        case .notConnected:
            "Not Connected"
        }
    }
}
