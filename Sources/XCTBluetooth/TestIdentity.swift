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


/// Tests the identity invariant of a `ByteCodable` implementation.
///
/// This function encodes a provided value into its byte representation, then
/// decodes it back into the value and asserts its equality using `XCTAssertEqual`.
///
/// - Parameter value: The value to encode and decode.
/// - Throws: Failed test.
public func testIdentity<T: ByteCodable & Equatable>(from value: T) throws {
    let data = value.encode()

    var decodingBuffer = ByteBuffer(data: data)

    let instance: T = try XCTUnwrap(T(from: &decodingBuffer))

    XCTAssertEqual(instance, value)
}


/// Tests the identity invariant of a `ByteCodable` implementation.
///
/// This function decodes the type from the provided byte representation, then
/// encodes it back into its byte representations and asserts its equality using `XCTAssertEqual`.
/// - Parameters:
///   - type: The type to test.
///   - data: The data representation to decode.
/// - Throws: Failed test.
public func testIdentity<T: ByteCodable>(of type: T.Type, from data: Data) throws {
    var decodingBuffer = ByteBuffer(data: data)

    let instance: T = try XCTUnwrap(T(from: &decodingBuffer))

    var encodingBuffer = ByteBuffer()
    encodingBuffer.reserveCapacity(data.count)

    instance.encode(to: &encodingBuffer)

    let encodingData = Data(buffer: encodingBuffer)
    XCTAssertEqual(encodingData, data)
}
