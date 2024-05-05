//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import BluetoothServices
import XCTest


final class MedFloatTests: XCTestCase {
    func testSpecialValues() {
        XCTAssertTrue(MedFloat16.nan.double.isNaN)
        XCTAssertTrue(MedFloat16.nres.double.isNaN)
        XCTAssertTrue(MedFloat16.reserved0.double.isNaN)
        XCTAssertEqual(MedFloat16.infinity.double, .infinity)
        XCTAssertEqual(MedFloat16.negativeInfinity.double, -Double.infinity)
    }

    func testDoubleConversion() {
        XCTAssertTrue(MedFloat16(.nan).isNaN)
        XCTAssertTrue(MedFloat16(.zero).isZero)
        XCTAssertEqual(MedFloat16(.infinity), .infinity)
        XCTAssertEqual(MedFloat16(-.infinity), .negativeInfinity)

        XCTAssertEqual(MedFloat16(123000.0), MedFloat16(exponent: 3, mantissa: 123))
        XCTAssertEqual(MedFloat16(12.34), MedFloat16(exponent: -2, mantissa: 1234))
        XCTAssertEqual(MedFloat16(0.0000012), MedFloat16(exponent: -7, mantissa: 12))

        XCTAssertEqual(MedFloat16(1234.0), MedFloat16(exponent: 0, mantissa: 1234))

        XCTAssertEqual(MedFloat16(-123000.0), MedFloat16(exponent: 3, mantissa: -123))
        XCTAssertEqual(MedFloat16(-12.34), MedFloat16(exponent: -2, mantissa: -1234))
        XCTAssertEqual(MedFloat16(-0.0000012), MedFloat16(exponent: -7, mantissa: -12))
    }

    func testBasicRepresentations() {
        let largeFloat = MedFloat16(exponent: 3, mantissa: 123)
        let smallFloat = MedFloat16(exponent: -2, mantissa: 1234)
        let smallSmallFloat = MedFloat16(exponent: -7, mantissa: 12)

        let zeroExponentFloat = MedFloat16(exponent: 0, mantissa: 1234)

        let negLargeFloat = MedFloat16(exponent: 3, mantissa: -123)
        let negSmallFloat = MedFloat16(exponent: -2, mantissa: -1234)
        let negSmallSmallFloat = MedFloat16(exponent: -7, mantissa: -12)

        XCTAssertEqual(largeFloat.exponent, 2)
        XCTAssertEqual(largeFloat.mantissa, 1230)
        XCTAssertEqual(smallFloat.exponent, -2)
        XCTAssertEqual(smallFloat.mantissa, 1234)
        XCTAssertEqual(smallSmallFloat.exponent, -8)
        XCTAssertEqual(smallSmallFloat.mantissa, 120)

        XCTAssertEqual(zeroExponentFloat.exponent, 0)
        XCTAssertEqual(zeroExponentFloat.mantissa, 1234)

        XCTAssertEqual(negLargeFloat.exponent, 2)
        XCTAssertEqual(negLargeFloat.mantissa, -1230)
        XCTAssertEqual(negSmallFloat.exponent, -2)
        XCTAssertEqual(negSmallFloat.mantissa, -1234)
        XCTAssertEqual(negSmallSmallFloat.exponent, -8)
        XCTAssertEqual(negSmallSmallFloat.mantissa, -120)

        XCTAssertTrue(largeFloat.isFinite)
        XCTAssertTrue(smallFloat.isFinite)
        XCTAssertTrue(smallSmallFloat.isFinite)
        XCTAssertTrue(negLargeFloat.isFinite)
        XCTAssertTrue(negSmallFloat.isFinite)
        XCTAssertTrue(negSmallSmallFloat.isFinite)

        XCTAssertEqual(largeFloat.double, 123000.0)
        XCTAssertEqual(smallFloat.double, 12.34)
        XCTAssertEqual(smallSmallFloat.double, 0.0000012)
        XCTAssertEqual(zeroExponentFloat.double, 1234.0)
        XCTAssertEqual(negLargeFloat.double, -123000.0)
        XCTAssertEqual(negSmallFloat.double, -12.34)
        XCTAssertEqual(negSmallSmallFloat.double, -0.0000012)


        XCTAssertEqual(MedFloat16.nan.description, "nan")
        XCTAssertEqual(MedFloat16.reserved0.description, "nan")
        XCTAssertEqual(MedFloat16.nres.description, "nres")
        XCTAssertEqual(MedFloat16.zero.description, "0.0")
        XCTAssertEqual(MedFloat16.infinity.description, "inf")
        XCTAssertEqual(MedFloat16.negativeInfinity.description, "-inf")

        XCTAssertEqual(largeFloat.description, "123000.0")
        XCTAssertEqual(smallFloat.description, "12.34")
        XCTAssertEqual(smallSmallFloat.description, "0.0000012")
        XCTAssertEqual(zeroExponentFloat.description, "1234.0")
        XCTAssertEqual(negLargeFloat.description, "-123000.0")
        XCTAssertEqual(negSmallFloat.description, "-12.34")
        XCTAssertEqual(negSmallSmallFloat.description, "-0.0000012")

        XCTAssertEqual(MedFloat16(127).description, "127.0")
        XCTAssertEqual(MedFloat16(12).description, "12.0")
    }

    func testEquality() {
        XCTAssertNotEqual(MedFloat16.nan, .nan)
        XCTAssertNotEqual(MedFloat16.nan, .nres)
        XCTAssertNotEqual(MedFloat16.nan, .infinity)
        XCTAssertNotEqual(MedFloat16.nan, MedFloat16(123))
        XCTAssertNotEqual(MedFloat16.nres, .nres)


        let float0 = MedFloat16(exponent: -1, mantissa: 130)
        let float1 = MedFloat16(exponent: 0, mantissa: 13)
        let float2 = MedFloat16(exponent: -2, mantissa: 1300)

        XCTAssertEqual(float0, float1)
        XCTAssertEqual(float0, float2)
        XCTAssertEqual(float1, float2)
        XCTAssertEqual(float0.description, float1.description)
        XCTAssertEqual(float1.description, float2.description)

        let float3 = MedFloat16(exponent: 1, mantissa: 10)
        let float4 = MedFloat16(exponent: 0, mantissa: 100)

        XCTAssertEqual(float3, float4)
        XCTAssertEqual(float3.description, float4.description)
    }

    // TODO: test int literal init + float literal
    func testLiteralInits() {
        XCTAssertEqual(MedFloat16(150000000000), .infinity)
        XCTAssertEqual(MedFloat16(-150000000000), .negativeInfinity)

        print(Float(sign: .plus, exponent: 267, significand: 0.6))
        print(MedFloat16(150000000000).description)
        print(MedFloat16(150000000000).debugDescription)
    }

    func testExactlyConversion() {
        XCTAssertEqual(MedFloat16(exactly: UInt8.max), 255)
        XCTAssertEqual(MedFloat16(exactly: Int8.max), 127)
        XCTAssertEqual(MedFloat16(exactly: 12400), 12400)

        XCTAssertNil(MedFloat16(exactly: Int16.max))
        XCTAssertNil(MedFloat16(exactly: UInt16.max))
        XCTAssertNil(MedFloat16(exactly: Int32.max))
        XCTAssertNil(MedFloat16(exactly: UInt32.max))
        XCTAssertNil(MedFloat16(exactly: Int64.max))
        XCTAssertNil(MedFloat16(exactly: UInt64.max))
    }

    func testOrdering() {
        // TODO: test ordering
    }

    func testAddition() { // TODO: add tests
        XCTAssertTrue((MedFloat16.infinity + .negativeInfinity).isNaN)
        XCTAssertTrue((MedFloat16.negativeInfinity + .infinity).isNaN)

        XCTAssertTrue((MedFloat16.nan + .nan).isNaN)
        XCTAssertTrue((MedFloat16.nres + .nres).isNaN)
        XCTAssertTrue((MedFloat16.nan + .nres).isNaN)
        XCTAssertTrue((MedFloat16.nres + .nan).isNaN)
        XCTAssertTrue((MedFloat16.reserved0 + .nan).isNaN)
        XCTAssertTrue((MedFloat16.nan + .reserved0).isNaN)
        XCTAssertTrue((MedFloat16.nres + .reserved0).isNaN)
        XCTAssertTrue((MedFloat16.reserved0 + .nres).isNaN)

        XCTAssertEqual(MedFloat16.infinity + .infinity, .infinity)
        XCTAssertEqual(MedFloat16.infinity + 12, .infinity)
        XCTAssertEqual(MedFloat16.infinity + -12, .infinity)

        XCTAssertEqual(MedFloat16.negativeInfinity + .negativeInfinity, .negativeInfinity)
        XCTAssertEqual(MedFloat16.negativeInfinity + 12, .negativeInfinity)
        XCTAssertEqual(MedFloat16.negativeInfinity + -12, .negativeInfinity)


        XCTAssertEqual(MedFloat16(15) + 12, 27)
        XCTAssertEqual(MedFloat16(15000000000) + 12000000000, .infinity)
        XCTAssertEqual(MedFloat16(1500000000) + 1200000000, 2700000000)
        XCTAssertEqual(MedFloat16(15000000) + 120000, 15120000)
    }

    func testMagnitude() {
        XCTAssertTrue(MedFloat16.nan.magnitude.isNaN)
        XCTAssertTrue(MedFloat16.nres.magnitude.isNRes)
        XCTAssertTrue(MedFloat16.reserved0.magnitude.isReserved0)

        XCTAssertEqual(MedFloat16.infinity.magnitude, .infinity)
        XCTAssertEqual(MedFloat16.negativeInfinity.magnitude, .infinity)

        XCTAssertEqual(MedFloat16.zero.magnitude, .zero)

        XCTAssertEqual(MedFloat16(12.5).magnitude, 12.5)
        XCTAssertEqual(MedFloat16(-12.5).magnitude, 12.5)
    }
}
