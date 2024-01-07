//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import NIOCore

// TODO: docs!


public protocol ByteDecodable { // TODO Data or ByteBuffer self conformance??
    init?(from byteBuffer: inout ByteBuffer)
}


public protocol ByteEncodable {
    func encode(to byteBuffer: inout ByteBuffer)
}


public typealias ByteCodable = ByteEncodable & ByteDecodable


// TODO: are those extensions needed?

extension ByteDecodable {
    public init?(data: Data) {
        var buffer = ByteBuffer(data: data)
        self.init(from: &buffer)
    }
}

extension ByteEncodable {
    public func encode() -> Data {
        var buffer = ByteBuffer()
        encode(to: &buffer)
        return buffer.getData(at: 0, length: buffer.readableBytes) ?? Data()
    }
}
