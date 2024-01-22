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
    /// Thrown when accessing a ``Characteristic`` that was not present.
    /// Either because the device wasn't connected or the characteristic is not present on the connected device.
    case notPresent

    
    /// Provides a human-readable description of the error.
    public var description: String {
        "\(errorDescription!): \(failureReason!)" // swiftlint:disable:this force_unwrapping
    }


    /// Provides a detailed description of the error.
    public var errorDescription: String? {
        switch self {
        case .incompatibleDataFormat:
            String(localized: "Decoding Error", bundle: .module)
        case .notPresent:
            String(localized: "Not Present", bundle: .module)
        }
    }


    public var failureReason: String? {
        switch self {
        case .incompatibleDataFormat:
            String(localized: "Could not decode byte representation into provided format.", bundle: .module)
        case .notPresent:
            String(localized: "The request characteristic was not present on the device.", bundle: .module)
        }
    }
}
