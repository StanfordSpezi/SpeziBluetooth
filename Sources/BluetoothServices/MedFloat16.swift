//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore


/// Medical 16-bit float representation using base 10.
///
/// The `MedFloat16` (or SFLOAT-Type) is a 16-bit value that uses 4-bit signed exponent to base 10 and 12-bit signed mantissa.
/// It can be used to accurately store decimal digits of base 10 decimal integers.
///
/// The value of the medfloat can be calculated using the the following formula, where `**` is exponentiation:
///
///         x.mantissa * (10 ** x.exponent)
public struct MedFloat16 {
    /// The bit pattern of the medfloat.
    public private(set) var bitPattern: UInt16

    /// The 4-bit signed exponent.
    ///
    /// The 4-bit signed exponent in two's complement, adjusted to Int8 two's complement representation.
    public var exponent: Int8 {
        var exponentBitPattern = UInt8(bitPattern >> 12)

        // We need to correct Int4 two's complement representation to Int8 two's complement:
        // If its larger than the largest positive uint4 number, we want to make sure that all upper 8 bits are flipped
        // in the int8 representation.
        if exponentBitPattern > UInt8(bitPattern: .maxInt4) {
            exponentBitPattern |= 0xF0
        }

        return Int8(bitPattern: exponentBitPattern)
    }

    /// The 12-bit signed exponent.
    ///
    /// The 12-bit signed exponent in two's complement, adjusted to Int16 two's complement representation.
    public var mantissa: Int16 {
        var mantissaBitPattern = bitPattern & 0x0FFF

        // See explanation in `exponent`. We correct Int12 two's complement representation to Int16 two's complement.
        if mantissaBitPattern > UInt16(bitPattern: .maxInt12) {
            mantissaBitPattern |= 0xF000
        }

        return Int16(bitPattern: mantissaBitPattern)
    }


    /// Initialize a medfloat from its 16-bit bit pattern.
    /// - Parameter bitPattern: The bit pattern as a unsigned, 16-bit integer.
    public init(bitPattern: UInt16) {
        self.bitPattern = bitPattern
    }


    /// Derive a medfloat16 from its exponent and mantissa.
    ///
    /// The value of the medfloat can be calculated using the the following formula, where `**` is exponentiation:
    ///
    ///         x.mantissa * (10 ** x.exponent)
    ///
    /// - Note: The `exponent` and `mantissa` are constrained to `Int4` and `Int12` resolution respectively.
    ///     Passing values exceeding this ranges will result in a ``nres`` value.
    ///
    /// - Note: Be aware that the closed range of `0x7FE`-`0x802` as the `mantissa` with an `exponent` of  zero are used
    ///     to represent special values like NaN, nRes or infinity.
    ///
    /// - Parameters:
    ///   - exponent: The signed Int4 exponent of the medfloat.
    ///   - mantissa: The signed Int12 exponent of the medfloat.
    public init(exponent: Int8, mantissa: Int16) {
        // check that exponent and mantissa are not out of range.
        if exponent > .maxInt4 || mantissa > .maxInt12
            || exponent < .minInt4 || mantissa < .minInt12 {
            self = mantissa >= 0 ? .infinity : .negativeInfinity
            return
        }

        var exponent = exponent
        var mantissa = mantissa

        MedFloat16.normalize(exponent: &exponent, mantissa: &mantissa)

        let exponentBitPattern = UInt8(bitPattern: exponent) & 0x0F
        let mantissaBitPattern = UInt16(bitPattern: mantissa) & 0x0FFF

        self.init(bitPattern: (UInt16(exponentBitPattern) << 12) | mantissaBitPattern)
    }
}


extension MedFloat16 {
    /// The zero value.
    public static let zero = MedFloat16(bitPattern: 0)

    /// Indicates invalid result.
    ///
    /// Indicates a invalid result form a computation step or to indicate missing data due to the hardware's inability to provide a valid measurement.
    /// Visual components should reflect this information by blanking the display or some other appropriate means.
    public static let nan = MedFloat16(bitPattern: 0x07FF)

    /// Positive infinity.
    public static let infinity = MedFloat16(bitPattern: 0x07FE)

    static let negativeInfinity = MedFloat16(bitPattern: 0x0802)

    /// Value cannot be represented with the available range or resolution.
    ///
    /// This situation could result from an overflow or underflow situation.
    public static let nres = MedFloat16(bitPattern: 0x0800)

    static let reserved0 = MedFloat16(bitPattern: 0x0801)

    /// The radix of the floating point number.
    public static let radix: Int = 10


    /// A Boolean value indicating whether the instance is NaN ("not a number").
    ///
    /// Because NaN is not equal to any value, including NaN, use this property
    /// instead of the equal-to operator (`==`) or not-equal-to operator (`!=`)
    /// to test whether a value is or is not NaN.
    public var isNaN: Bool {
        bitPattern == MedFloat16.nan.bitPattern
    }

    /// Determine if float is zero.
    ///
    /// There are multiple representations of zero (all these, where the mantissa is set to zero, with an arbitrary combination of exponents).
    public var isZero: Bool {
        mantissa == 0
    }

    /// A Boolean value indicating whether the instance is nRes ("not at this resolution").
    ///
    /// Because nRes is not equal to any value, including nRes, use this property
    /// instead of the equal-to operator (`==`) or not-equal-to operator (`!=`)
    /// to test whether a value is or is not nRes.
    public var isNRes: Bool {
        bitPattern == MedFloat16.nres.bitPattern
    }

    /// Reserved special value.
    var isReserved0: Bool {
        bitPattern == MedFloat16.reserved0.bitPattern
    }

    /// Any NaN-like value (NaN, NRes, reserved0).
    var isNaNLike: Bool {
        isNaN || isNRes || isReserved0
    }

    /// A Boolean value indicating whether this instance is finite.
    ///
    /// All values other than NaN, nRes and infinity are considered finite, whether
    /// normal or subnormal.  For NaN and nRes, both `isFinite` and ``isInfinite`` are false.
    public var isFinite: Bool {
        !isNaN && !isNRes && !isInfinite
    }

    /// A Boolean value indicating whether the instance is infinite.
    ///
    /// For NaN and nRes, both ``isFinite`` and `isInfinite` are false.
    public var isInfinite: Bool {
        bitPattern == MedFloat16.infinity.bitPattern
            || bitPattern == MedFloat16.negativeInfinity.bitPattern
    }


    /// The sign of the floating-point value.
    ///
    /// The sign is `minus` if the mantissa has a negative value and `plus` otherwise.
    public var sign: FloatingPointSign {
        if mantissa < 0 {
            .minus
        } else {
            .plus
        }
    }
}


extension MedFloat16 {
    private static func normalize(exponent: inout Int8, mantissa: inout Int16) {
        while exponent > .minInt4
                && !mantissa.multipliedReportingOverflow(by: 10).overflow
                && (mantissa * 10 <= .medFloat16MantissaMax)
                && (mantissa * 10 >= .medFloat16mantissaMin) {
            mantissa *= 10
            exponent -= 1
        }
    }

    mutating func normalize() {
        self.bitPattern = normalized().bitPattern
    }

    func normalized() -> MedFloat16 {
        // MedFloat16.normalize is called as part of the initializer
        MedFloat16(exponent: exponent, mantissa: mantissa)
    }
}


extension MedFloat16 {
    /// Double approximation of the medfloat.
    public var double: Double {
        switch bitPattern {
        case MedFloat16.nan.bitPattern, MedFloat16.nres.bitPattern, MedFloat16.reserved0.bitPattern:
            return .nan
        case MedFloat16.infinity.bitPattern:
            return .infinity
        case MedFloat16.negativeInfinity.bitPattern:
            return -Double.infinity
        default:
            break
        }

        let magnitude = pow(10.0, Double(exponent))

        return Double(mantissa) * magnitude
    }


    /// Creates a new instance that approximates the given value.
    ///
    /// The value of `other` is rounded to a representable value, if necessary.
    /// A NaN passed as `other` results in medfloat NaN.
    /// Values that are larger or smaller than what a medfloat16 can represent results in positive or negative infinity.
    ///
    /// - Parameter other: The value to use for the new instance.
    public init(_ other: Double) {
        if other.isNaN {
            self = .nan
        } else if other > .medFloat16Max {
            self = .infinity
        } else if other < .medFloat16Min {
            self = .negativeInfinity
        } else if other >= -.medFloat16Epsilon && other <= .medFloat16Epsilon {
            self = .zero
        } else {
            var exponent: Int8 = 0 // to base 10
            var mantissaTemp = abs(other) // we slowly scale up/down the exponent to have mantissa fit into 12-bit two's complement

            // scale up if number is too big
            while mantissaTemp > Double(Int16.medFloat16MantissaMax) {
                mantissaTemp /= 10
                exponent += 1

                if exponent > .maxInt4 {
                    preconditionFailure("Precondition check didn't properly check for infinity, medfloat16 from double \(other)")
                }
            }

            // scale down if number is to small
            while mantissaTemp < 1 {
                mantissaTemp *= 10
                exponent -= 1

                if exponent < .minInt4 {
                    preconditionFailure("Precondition check didn't properly check for epsilon, medfloat16 from double \(other)")
                }
            }

            // scale down if number needs more precision
            var mantissaDiff = Self.mantissaPrecisionDiff(mantissaTemp)
            while mantissaDiff > 0.5 && exponent > .minInt4 && (mantissaTemp * 10 <= Double(Int16.medFloat16MantissaMax)) {
                mantissaTemp *= 10
                exponent -= 1

                mantissaDiff = Self.mantissaPrecisionDiff(mantissaTemp)
            }

            let mantissa = Int16(round((other.sign == .minus ? -1 : 1) * mantissaTemp))

            self.init(exponent: exponent, mantissa: mantissa)
            assert(self.isFinite, "Double initialization failed and resulted in \(description)")
        }
    }

    
    private static func mantissaPrecisionDiff(_ mantissa: Double) -> Double {
        let smantissa = round(mantissa * .medFloat16Precision)
        let rmantissa = round(mantissa) * .medFloat16Precision
        return abs(smantissa - rmantissa)
    }
}


extension MedFloat16: Sendable {}


extension MedFloat16: Equatable {
    public static func == (lhs: MedFloat16, rhs: MedFloat16) -> Bool {
        if lhs.isNaNLike || rhs.isNaNLike {
            return false // any nan-like is never equal
        }

        if lhs.isZero && rhs.isZero {
            return true
        }

        return lhs.normalized().bitPattern == rhs.normalized().bitPattern
    }
}


extension MedFloat16: Comparable {
    public static func < (lhs: MedFloat16, rhs: MedFloat16) -> Bool {
        if lhs.isNaNLike || rhs.isNaNLike {
            return false // any nan-like does never compare
        }

        switch (lhs.bitPattern, rhs.bitPattern) {
        case let (MedFloat16.negativeInfinity.bitPattern, rhsBits):
            // `-infinity` compares less than all values except for itself and NaN-like values
            return rhsBits != MedFloat16.negativeInfinity.bitPattern && !rhs.isNaNLike
        case let (lhsBits, MedFloat16.infinity.bitPattern):
            // every value except for NaN and `+infinity` compares less than
            return lhsBits != MedFloat16.infinity.bitPattern && !lhs.isNaNLike
        case (_, MedFloat16.negativeInfinity.bitPattern):
            return false // nothing is ever smaller than negative infinity
        case (MedFloat16.infinity.bitPattern, _):
            return false // nothing is ever greater than positive infinity
        default:
            break
        }

        if lhs.isZero {
            return 0 < rhs.mantissa
        } else if rhs.isZero {
            return lhs.mantissa < 0
        } else {
            return lhs.double < rhs.double
        }
    }
}


extension MedFloat16: Hashable {
    public func hash(into hasher: inout Hasher) {
        if isZero {
            hasher.combine(MedFloat16.zero.bitPattern)
        } else {
            hasher.combine(normalized().bitPattern)
        }
    }
}


extension MedFloat16: CustomStringConvertible {
    private var specialValueString: String? {
        if isNaN || isReserved0 {
            return "nan"
        } else if isNRes {
            return "nres"
        } else if bitPattern == MedFloat16.infinity.bitPattern {
            return "inf"
        } else if bitPattern == MedFloat16.negativeInfinity.bitPattern {
            return "-inf"
        } else if isZero {
            return "0.0" // map all zeros to same representation
        }
        return nil
    }

    public var description: String {
        if let specialValueString {
            return specialValueString
        }

        let exponent = exponent
        let mantissa = mantissa

        var description = mantissa.description

        if exponent > 0 {
            description
                .append(String(repeating: "0", count: Int(exponent)))

            description
                .append(".0")
        } else if exponent == 0 {
            description
                .append(".0")
        } else { // exponent < 0
            let digitCount = description.count - (sign == .minus ? 1 : 0)

            if -exponent < digitCount {
                let dotIndex = description.index(description.endIndex, offsetBy: Int(exponent))

                description.insert(".", at: dotIndex)
            } else {
                let insertionIndex = sign == .minus
                    ? description.index(after: description.startIndex) // skipping the "-"
                    : description.startIndex

                let zeroPrefix = String(repeating: "0", count: Int(-exponent) - digitCount)
                description.insert(contentsOf: zeroPrefix, at: insertionIndex)

                description.insert(contentsOf: "0.", at: insertionIndex)
            }

            // remove unnecessary trailing zeros
            while description.last == "0" {
                description.removeLast()
            }

            if description.last == "." {
                description.append("0")
            }
        }

        return description
    }
}


extension MedFloat16: CustomDebugStringConvertible {
    public var debugDescription: String {
        if let specialValueString {
            return specialValueString
        }

        return "\(mantissa) * (10 ** \(exponent))"
    }
}


extension MedFloat16: ExpressibleByFloatLiteral {
    /// Creates an instance initialized to the specified floating-point value.
    ///
    /// - Parameter value: The value to create.
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}


extension MedFloat16: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        let doubleValue = Double(value) // cheap route here
        self.init(doubleValue)
    }
}

extension MedFloat16: AdditiveArithmetic {
    public static func + (lhs: MedFloat16, rhs: MedFloat16) -> MedFloat16 {
        // We are going the cheap route here! There, is way too much to check for otherwise.
        MedFloat16(lhs.double + rhs.double)
    }

    public static func - (lhs: MedFloat16, rhs: MedFloat16) -> MedFloat16 {
        lhs + (-rhs)
    }
}


extension MedFloat16: Numeric {
    public var magnitude: MedFloat16 { // basically an abs function
        if isNaNLike || bitPattern == MedFloat16.infinity.bitPattern {
            return self
        } else if bitPattern == MedFloat16.negativeInfinity.bitPattern {
            return .infinity
        }

        let mantissa = mantissa
        if mantissa >= 0 {
            return self
        }

        // otherwise we are negative
        return -self
    }


    public init?<T: BinaryInteger>(exactly source: T) {
        var mantissa = source
        var exponent: Int8 = 0

        while !MedFloat16.fitsMantissa(mantissa) {
            if mantissa.isMultiple(of: 10) && exponent + 1 < .maxInt4 {
                mantissa /= 10
                exponent += 1
            } else {
                return nil // we can't adjust anymore!
            }
        }

        self.init(exponent: exponent, mantissa: Int16(mantissa))
    }

    private static func fitsMantissa<T: BinaryInteger>(_ source: T) -> Bool {
        let words = source.magnitude.words // words from least significant to most significant

        guard let first = words.first else {
            return true
        }

        guard words.suffix(from: 1).allSatisfy({ $0 == 0 }) else {
            return false // ensure there aren't any more words that contain ones
        }

        // check that the exponent bytes and the most significant mantissa bit is zero of second word.
        return first & (UInt.max << 11) == 0
    }

    public static func * (lhs: MedFloat16, rhs: MedFloat16) -> MedFloat16 {
        // We are going the cheap route here! There, is way too much to check for otherwise.
        MedFloat16(lhs.double * rhs.double)
    }

    public static func *= (lhs: inout MedFloat16, rhs: MedFloat16) {
        lhs.bitPattern = (lhs * rhs).bitPattern
    }
}


extension MedFloat16: SignedNumeric {
    public prefix static func - (operand: MedFloat16) -> MedFloat16 {
        var operand = operand
        operand.negate()
        return operand
    }

    public mutating func negate() {
        if isNaNLike {
            return
        }
        
        switch bitPattern {
        case MedFloat16.infinity.bitPattern:
            bitPattern = MedFloat16.negativeInfinity.bitPattern
        case MedFloat16.negativeInfinity.bitPattern:
            bitPattern = MedFloat16.infinity.bitPattern
        default:
            let mantissa = -self.mantissa

            let mantissaBits = UInt16(bitPattern: mantissa) & 0x0FFF

            bitPattern &= 0xF000 // reset mantissa bits
            bitPattern |= mantissaBits
        }
    }
}


extension MedFloat16: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let bitPattern = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.init(bitPattern: bitPattern)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        bitPattern.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension Double {
    /// Maximum value in Double representation for a `medfloat16`.
    ///
    ///     (2 ** 11 - 3) * 10 ** 7
    fileprivate static let medFloat16Max: Double = 20450000000.0
    /// Minimum value in Double representation for a `medfloat16`.
    ///
    ///     -(2 ** 11 - 3) * 10 ** 7
    fileprivate static let medFloat16Min: Double = -medFloat16Max
    /// The minimum precision of a `medfloat16`.
    ///
    ///     10 ** -8
    fileprivate static let medFloat16Epsilon: Double = 1e-8
    /// `10 ** upper(11 * log(2) / log(10))`
    fileprivate static let medFloat16Precision: Double = 10000
}


extension Int8 {
    fileprivate static let maxInt4 = Int8(bitPattern: 0x7)
    fileprivate static let minInt4 = Int8(bitPattern: 0xF8)
}


extension Int16 {
    fileprivate static let maxInt12 = Int16(bitPattern: 0x7FF)
    fileprivate static let minInt12 = Int16(bitPattern: 0xF800)
    /// `(2 ** 11 - 3)`
    /// `MedFloat16.infinity - 1`
    fileprivate static let medFloat16MantissaMax: Int16 = 0x07FD
    /// `MedFloat16.negativeInfinity + 1` but with most significant byte adjusted to Int16 representation.
    fileprivate static let medFloat16mantissaMin = Int16(bitPattern: 0xF803)
}

// swiftlint:disable:this file_length
