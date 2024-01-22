//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


extension CBError: LocalizedError {
    public var errorDescription: String? {
        "CoreBluetooth Error"
    }

    public var failureReason: String? {
        localizedDescription
    }
}


extension CBATTError: LocalizedError {
    public var errorDescription: String? {
        "CoreBluetooth ATT Error"
    }

    public var failureReason: String? {
        localizedDescription
    }
}
