//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


enum CharacteristicOnChangeHandler {
    case value(_ closure: (Data) -> Void)
    case instance(_ closure: (GATTCharacteristic?) -> Void)
}
