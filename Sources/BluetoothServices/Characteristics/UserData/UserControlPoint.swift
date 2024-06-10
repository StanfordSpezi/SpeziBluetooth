//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore
import SpeziBluetooth


public struct UserControlPoint<Parameter: UserControlPointParameter> {
    public var opCode: UserControlPointOpCode {
        parameter.opCode
    }

    public let parameter: Parameter

    public init(_ parameter: Parameter) {
        self.parameter = parameter
    }
}


extension UserControlPoint: Hashable, Sendable {}


extension UserControlPoint: ControlPointCharacteristic {}


extension UserControlPoint: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let opCode = UserControlPointOpCode(from: &byteBuffer, preferredEndianness: endianness),
              let parameter = Parameter(from: &byteBuffer, preferredEndianness: endianness, opCode: opCode) else {
            return nil
        }

        self.init(parameter)
    }
    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        opCode.encode(to: &byteBuffer, preferredEndianness: endianness) // TODO: should we move encoding to Parameter? could avoid custom initializer!
        parameter.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
