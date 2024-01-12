//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziBluetooth
import XCTest
import NIO


final class ByteCodableTests: XCTestCase {
    func testData() throws {
        let data = try XCTUnwrap(Data(hex: "0xAABBCCDDEE"))

        try testIdentity(of: Data.self, using: data)
    }

    func testByteBuffer() {

    }
}



// TODO: move this to a XCTBluetooth?

// TODO: a test identity starting from the type?

func testIdentity<T: ByteCodable>(of type: T.Type, using data: Data) throws {
    var decodingBuffer = ByteBuffer(data: data)

    let instance: T = try XCTUnwrap(T(from: &decodingBuffer))

    var encodingBuffer = ByteBuffer()
    encodingBuffer.reserveCapacity(data.count)

    instance.encode(to: &encodingBuffer)

    let encodingData = Data(buffer: encodingBuffer)
    XCTAssertEqual(encodingData, data)
}
