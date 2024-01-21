//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO
@testable @_spi(TestingSupport) import SpeziBluetooth // swiftlint:disable:this attributes
import XCTBluetooth
import XCTest


final class ByteCodableTests: XCTestCase {
    func testData() throws {
        let data = try XCTUnwrap(Data(hex: "0xAABBCCDDEE"))

        try testIdentity(of: Data.self, from: data)
    }

    func testBoolean() throws {
        let trueData = try XCTUnwrap(Data(hex: "0x01"))
        try testIdentity(of: Bool.self, from: trueData)

        let falseData = try XCTUnwrap(Data(hex: "0x00"))
        try testIdentity(of: Bool.self, from: falseData)

        var empty = ByteBuffer()
        XCTAssertNil(Bool(from: &empty))
    }

    func testString() throws {
        let data = try XCTUnwrap("Hello World".data(using: .utf8))
        try testIdentity(of: String.self, from: data)

        var empty = ByteBuffer()
        XCTAssertEqual(String(from: &empty), "")
    }

    func testInt8() throws {
        try testIdentity(from: Int8.max)
        try testIdentity(from: Int8.min)
    }

    func testInt16() throws {
        try testIdentity(from: Int16.max)
        try testIdentity(from: Int16.min)
    }

    func testInt32() throws {
        try testIdentity(from: Int32.max)
        try testIdentity(from: Int32.min)
    }

    func testInt64() throws {
        try testIdentity(from: Int64.max)
        try testIdentity(from: Int64.min)
    }

    func testUInt8() throws {
        try testIdentity(from: UInt8.max)
        try testIdentity(from: UInt8.min)

        var empty = ByteBuffer()
        XCTAssertNil(UInt8(from: &empty))
    }

    func testUInt16() throws {
        try testIdentity(from: UInt16.max)
        try testIdentity(from: UInt16.min)
    }

    func testUInt32() throws {
        try testIdentity(from: UInt32.max)
        try testIdentity(from: UInt32.min)
    }

    func testUInt64() throws {
        try testIdentity(from: UInt64.max)
        try testIdentity(from: UInt64.min)
    }
}
