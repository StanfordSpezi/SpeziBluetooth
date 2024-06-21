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


/// The description of a general response.
///
/// Used to represent the content of a ``RecordAccessOpCode/responseCode`` operation.
public struct RecordAccessGeneralResponse {
    /// The operation code of the request this response is triggered from.
    public let requestOpCode: RecordAccessOpCode
    /// The response code.
    public let response: RecordAccessResponseCode


    /// Initialize a new general response.
    /// - Parameters:
    ///   - requestOpCode: The request code.
    ///   - response: The response code.
    public init(requestOpCode: RecordAccessOpCode, response: RecordAccessResponseCode) {
        self.requestOpCode = requestOpCode
        self.response = response
    }
}


extension RecordAccessGeneralResponse: Hashable, Sendable {}


extension RecordAccessGeneralResponse: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let requestOpCode = RecordAccessOpCode(from: &byteBuffer),
              let response = RecordAccessResponseCode(from: &byteBuffer) else {
            return nil
        }

        self.init(requestOpCode: requestOpCode, response: response)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        requestOpCode.encode(to: &byteBuffer)
        response.encode(to: &byteBuffer)
    }
}
