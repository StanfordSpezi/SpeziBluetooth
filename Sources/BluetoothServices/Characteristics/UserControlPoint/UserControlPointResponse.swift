//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


public enum UserControlPointResponse {
    case success(UserControlPointResponseParameter? = nil)
    case opCodeNotSupported
    case invalidParameter
    case operationFailed
    case userNotAuthorized


    public var responseValue: UserControlPointResponseValue {
        switch self {
        case .success:
            return .success
        case .opCodeNotSupported:
            return .opCodeNotSupported
        case .invalidParameter:
            return .invalidParameter
        case .operationFailed:
            return .operationFailed
        case .userNotAuthorized:
            return .userNotAuthorized
        }
    }
}


extension UserControlPointResponse: Hashable, Sendable {}


extension UserControlPointResponse: ByteEncodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness, requestOpCode: UserControlPointOpCode) {
        guard let responseValue = UserControlPointResponseValue(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        switch responseValue {
        case .success:
            let parameter: UserControlPointResponseParameter?
            switch requestOpCode {
            case .registerNewUser, .deleteUser:
                guard let userIndex = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
                    return nil
                }
                parameter = .userIndex(userIndex)
            case .listAllUsers:
                guard let numberOfUsers = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
                    return nil
                }
                parameter = .numberOfUsers(numberOfUsers)
            default:
                parameter = nil
            }

            self = .success(parameter)
        case .opCodeNotSupported:
            self = .opCodeNotSupported
        case .invalidParameter:
            self = .invalidParameter
        case .operationFailed:
            self = .operationFailed
        case .userNotAuthorized:
            self = .userNotAuthorized
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        responseValue.encode(to: &byteBuffer, preferredEndianness: endianness)
        switch self {
        case let .success(parameter):
            if let parameter {
                parameter.rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
            }
        default:
            break
        }
    }
}
