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

        XCTAssertTrue(MedFloat16.nan.float.isNaN)
        XCTAssertTrue(MedFloat16.nres.float.isNaN)
        XCTAssertTrue(MedFloat16.reserved0.float.isNaN)
        XCTAssertEqual(MedFloat16.infinity.float, .infinity)
        XCTAssertEqual(MedFloat16.negativeInfinity.float, -Float.infinity)

        print(Int64.max)
        print(Float(integerLiteral: .max).description)
        print(Float(integerLiteral: .max).debugDescription)
        print(Float(integerLiteral: .max).bitPattern)
        print(Double(integerLiteral: .max).description)
        print(Double(integerLiteral: .max).debugDescription)
        print(Double(integerLiteral: .max).bitPattern)
    }

    func testBasicRepresentations() {
        let largeFloat = MedFloat16(exponent: 3, mantissa: 123)
        let smallFloat = MedFloat16(exponent: -2, mantissa: 1234)
        let smallSmallFloat = MedFloat16(exponent: -7, mantissa: 12)

        let zeroExponentFloat = MedFloat16(exponent: 0, mantissa: 1234)

        let negLargeFloat = MedFloat16(exponent: 3, mantissa: -123)
        let negSmallFloat = MedFloat16(exponent: -2, mantissa: -1234)
        let negSmallSmallFloat = MedFloat16(exponent: -7, mantissa: -12)

        XCTAssertEqual(largeFloat.exponent, 3)
        XCTAssertEqual(largeFloat.mantissa, 123)
        XCTAssertEqual(smallFloat.exponent, -2)
        XCTAssertEqual(smallFloat.mantissa, 1234)
        XCTAssertEqual(smallSmallFloat.exponent, -7)
        XCTAssertEqual(smallSmallFloat.mantissa, 12)

        XCTAssertEqual(zeroExponentFloat.exponent, 0)
        XCTAssertEqual(zeroExponentFloat.mantissa, 1234)

        XCTAssertEqual(negLargeFloat.exponent, 3)
        XCTAssertEqual(negLargeFloat.mantissa, -123)
        XCTAssertEqual(negSmallFloat.exponent, -2)
        XCTAssertEqual(negSmallFloat.mantissa, -1234)
        XCTAssertEqual(negSmallSmallFloat.exponent, -7)
        XCTAssertEqual(negSmallSmallFloat.mantissa, -12)

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
    }
}
