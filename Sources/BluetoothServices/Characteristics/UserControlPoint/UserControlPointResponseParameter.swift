//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public enum UserControlPointResponseParameter {
    case userIndex(UInt8)
    case numberOfUsers(UInt8)


    public var rawValue: UInt8 {
        switch self {
        case let .userIndex(value):
            return value
        case let .numberOfUsers(value):
            return value
        }
    }
}


extension UserControlPointResponseParameter: Hashable, Sendable {}
