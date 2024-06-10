//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


// TODO: CharacteristicAccessor extensions?


public enum UserControlPointGenericParameter {
    case registerNewUser(consentCode: UInt16)
    case consent(userIndex: UInt8, consentCode: UInt16)
    case deleteUserData
    case listAllUsers
    case deleterUser(userIndex: UInt8)
    case response(
        requestOpCode: UserControlPointOpCode,
        response: UserControlPointResponse
    )
}


extension UserControlPointGenericParameter: Hashable, Sendable {}


extension UserControlPointGenericParameter: UserControlPointParameter {
    public var opCode: UserControlPointOpCode {
        switch self {
        case .registerNewUser:
            return .registerNewUser
        case .consent:
            return .consent
        case .deleteUserData:
            return .deleteUserData
        case .listAllUsers:
            return .listAllUsers
        case .deleterUser:
            return .deleteUser
        case .response:
            return .response
        }
    }

    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness, opCode: UserControlPointOpCode) {
        switch opCode {
        case .registerNewUser:
            guard let consentCode = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .registerNewUser(consentCode: consentCode)
        case .consent:
            guard let userIndex = UInt8(from: &byteBuffer, preferredEndianness: endianness),
                  let consentCode = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .consent(userIndex: userIndex, consentCode: consentCode)
        case .deleteUserData:
            self = .deleteUserData
        case .listAllUsers:
            self = .listAllUsers
        case .deleteUser:
            guard let userIndex = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self = .deleterUser(userIndex: userIndex)
        case .response:
            guard let requestOpCode = UserControlPointOpCode(from: &byteBuffer, preferredEndianness: endianness),
                  let response = UserControlPointResponse(from: &byteBuffer, preferredEndianness: endianness, requestOpCode: requestOpCode) else {
                return nil
            }
            self = .response(requestOpCode: requestOpCode, response: response)
        default:
            return nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        switch self {
        case let .registerNewUser(consentCode):
            consentCode.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .consent(userIndex, consentCode):
            userIndex.encode(to: &byteBuffer, preferredEndianness: endianness)
            consentCode.encode(to: &byteBuffer, preferredEndianness: endianness)
        case .deleteUserData:
            break
        case .listAllUsers:
            break
        case let .deleterUser(userIndex):
            userIndex.encode(to: &byteBuffer, preferredEndianness: endianness)
        case let .response(requestOpCode, response):
            requestOpCode.encode(to: &byteBuffer, preferredEndianness: endianness)
            response.encode(to: &byteBuffer, preferredEndianness: endianness)
        }
    }
}
