//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore

public struct RecordAccessGeneralResponse {
    public let requestOpCode: RecordAccessOpCode
    public let response: RecordAccessResponseCode


    public init(requestOpCode: RecordAccessOpCode, response: RecordAccessResponseCode) {
        self.requestOpCode = requestOpCode
        self.response = response
    }
}


extension RecordAccessGeneralResponse: Hashable, Sendable {}


extension RecordAccessGeneralResponse: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let requestOpCode = RecordAccessOpCode(from: &byteBuffer, preferredEndianness: endianness),
              let response = RecordAccessResponseCode(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.init(requestOpCode: requestOpCode, response: response)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        requestOpCode.encode(to: &byteBuffer, preferredEndianness: endianness)
        response.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}
