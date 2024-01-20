//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


enum CharacteristicAccessContinuation {
    case read(_ continuation: [CheckedContinuation<Data, Error>])
    case write(_ continuation: CheckedContinuation<Data, Error>)
}
