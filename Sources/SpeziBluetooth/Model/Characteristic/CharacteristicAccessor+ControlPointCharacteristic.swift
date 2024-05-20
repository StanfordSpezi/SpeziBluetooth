//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension CharacteristicAccessor where Value: ControlPointCharacteristic {
    public func sendRequest(_ value: Value) async throws -> Value {
        guard let injection else {
            throw BluetoothError.notPresent(characteristic: configuration.id)
        }

        return try await injection.sendRequest(value)
    }
}
