//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension CharacteristicAccessor where Value: ControlPointCharacteristic {
    /// Send request to a control point characteristics and await the response.
    ///
    /// This method can be used with ``ControlPointCharacteristic`` to send a request and await the response of the peripheral.
    ///
    /// - Important: The response is delivered using a notification. In order to use this method you must enable notifications
    ///     for the characteristics (see ``enableNotifications(_:)``).
    ///
    /// - Parameter value: The request you want to send.
    /// - Returns: The response returned from the peripheral.
    /// - Throws: Throws an `CBError` or `CBATTError` if the write fails.
    ///     It might also throw a ``BluetoothError/notPresent(service:characteristic:)``,
    ///     ``BluetoothError/controlPointRequiresNotifying(service:characteristic:)`` or
    ///     ``BluetoothError/controlPointInProgress(service:characteristic:)`` error.
    public func sendRequest(_ value: Value) async throws -> Value {
        guard let injection else {
            throw BluetoothError.notPresent(characteristic: configuration.id)
        }

        return try await injection.sendRequest(value)
    }
}
