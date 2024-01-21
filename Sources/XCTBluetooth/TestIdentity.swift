//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import NIO
import SpeziBluetooth
import XCTest


public func testIdentity<T: ByteCodable & Equatable>(from value: T) throws {
    let data = value.encode()

    var decodingBuffer = ByteBuffer(data: data)

    let instance: T = try XCTUnwrap(T(from: &decodingBuffer))

    XCTAssertEqual(instance, value)
}


public func testIdentity<T: ByteCodable>(of type: T.Type, from data: Data) throws {
    var decodingBuffer = ByteBuffer(data: data)

    let instance: T = try XCTUnwrap(T(from: &decodingBuffer))

    var encodingBuffer = ByteBuffer()
    encodingBuffer.reserveCapacity(data.count)

    instance.encode(to: &encodingBuffer)

    let encodingData = Data(buffer: encodingBuffer)
    XCTAssertEqual(encodingData, data)
}
