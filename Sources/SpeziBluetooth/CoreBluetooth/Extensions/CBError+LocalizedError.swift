//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


extension CBError: @retroactive LocalizedError {
    public var errorDescription: String? {
        "CoreBluetooth Error"
    }

    public var failureReason: String? {
        localizedDescription
    }
}


extension CBATTError: @retroactive LocalizedError {
    public var errorDescription: String? {
        "CoreBluetooth ATT Error"
    }

    public var failureReason: String? {
        localizedDescription
    }
}
