//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


/// Represents errors that can occur during Bluetooth operations.
public enum BluetoothError: Error, CustomStringConvertible, LocalizedError {
    /// Could not decode the ByteBuffer into the provided ByteDecodable.
    case incompatibleDataFormat
    /// Thrown when accessing a ``Characteristic`` that was not present.
    /// Either because the device wasn't connected or the characteristic is not present on the connected device.
    case notPresent(service: CBUUID? = nil, characteristic: CBUUID)
    /// Control Point command requires notifications to be enabled.
    /// This error is thrown if one tries to send a request to a ``ControlPointCharacteristic`` but notifications haven't been enabled for that characteristic.
    case controlPointRequiresNotifying(service: CBUUID, characteristic: CBUUID)
    /// Request is in progress.
    /// Request was sent to a control point characteristic while a different request is waiting for a response.
    case controlPointInProgress(service: CBUUID, characteristic: CBUUID)

    
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
        case .controlPointRequiresNotifying, .controlPointInProgress:
            String(localized: "Control Point Error", bundle: .module)
        }
    }


    public var failureReason: String? {
        switch self {
        case .incompatibleDataFormat:
            String(localized: "Could not decode byte representation into provided format.", bundle: .module)
        case let .notPresent(service, characteristic):
            String(localized: "The requested characteristic \(characteristic) on \(service?.uuidString ?? "?") was not present on the device.", bundle: .module)
        case let .controlPointRequiresNotifying(service, characteristic):
            String(localized: "Control point request was sent to \(characteristic) on \(service) but notifications weren't enabled for that characteristic.", bundle: .module)
        case let .controlPointInProgress(service, characteristic):
            String(localized: "Control point request was sent to \(characteristic) on \(service) while waiting for a response to a previous request.", bundle: .module)
        }
    }
}
