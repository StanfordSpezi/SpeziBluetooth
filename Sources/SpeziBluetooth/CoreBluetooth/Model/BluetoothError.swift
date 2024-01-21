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
    case notConnected

    
    /// Provides a human-readable description of the error.
    public var description: String {
        "\(errorDescription!): \(failureReason!)" // swiftlint:disable:this force_unwrapping
    }


    /// Provides a detailed description of the error.
    public var errorDescription: String? {
        switch self {
        case .incompatibleDataFormat:
            String(localized: "Decoding Error", bundle: .module)
        case .notConnected:
            String(localized: "Not Connected", bundle: .module)
        }
    }


    public var failureReason: String? {
        switch self {
        case .incompatibleDataFormat:
            String(localized: "Could not decode byte representation into provided format.", bundle: .module)
        case .notConnected:
            String(localized: "Peripheral is not connected.", bundle: .module)
        }
    }
}
