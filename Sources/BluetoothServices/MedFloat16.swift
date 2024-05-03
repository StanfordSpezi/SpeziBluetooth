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

// TODO: move file?? SpeziNetworking (finally?)

// TODO: protocol?

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
    public let bitPattern: UInt16

    /// The 4-bit signed exponent.
    ///
    /// The 4-bit signed exponent in two's complement, adjusted to Int8 two's complement representation.
    public var exponent: Int8 {
        var exponentBitPattern = UInt8(bitPattern >> 12)

        // We need to correct Int4 two's complement representation to Int8 two's complement:
        // If its larger than the largest positive uint4 number, we want to make sure that all upper 8 bits are flipped
        // in the int8 representation.
        if exponentBitPattern > MedFloat16.maxInt4 {
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
        if mantissaBitPattern > MedFloat16.maxInt12 {
            mantissaBitPattern |= 0xF000
        }

        return Int16(bitPattern: mantissaBitPattern)
    }


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

        // TODO: properly convert to reserved Doubles?
        let magnitude = pow(10.0, Double(exponent))

        return Double(mantissa) * magnitude
    }

    /// Float approximation of the medfloat.
    public var float: Float { // TODO: do we want to support that?
        // using the double value for best precision in the conversion.
        Float(double)
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
        if exponent > MedFloat16.maxInt4 || exponent < MedFloat16.minInt4
            || mantissa > MedFloat16.maxInt12 || mantissa < MedFloat16.minInt12 {
            self = .nres // TODO: what is +- infinity used then?
            return
        }

        let exponentBitPattern = UInt8(bitPattern: exponent) & 0x0F
        let mantissaBitPattern = UInt16(bitPattern: mantissa) & 0x0FFF

        self.init(bitPattern: (UInt16(exponentBitPattern) << 12) | mantissaBitPattern)
    }

    // TODO: can we convert from a e.g., double? se bytelib implementation
}


extension MedFloat16 {
    public static let zero = MedFloat16(bitPattern: 0)

    /// Indicates invalid result.
    ///
    /// Indicates a invalid result form a computation step or to indicate missing data due to the hardware's inability to provide a valid measurement.
    /// Visual components should reflect this information by blanking the display or some other appropriate means.
    public static let nan = MedFloat16(bitPattern: 0x07FF)

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


extension MedFloat16: Sendable {}


extension MedFloat16: Equatable {
    public static func == (lhs: MedFloat16, rhs: MedFloat16) -> Bool {
        switch (lhs.bitPattern, rhs.bitPattern) {
        case (MedFloat16.nan.bitPattern, _),
            (MedFloat16.nres.bitPattern, _),
            (MedFloat16.reserved0.bitPattern, _),
            (_, MedFloat16.nan.bitPattern),
            (_, MedFloat16.nres.bitPattern),
            (_, MedFloat16.reserved0.bitPattern):
            return false // any nan-like is never equal
        default:
            return lhs.bitPattern == rhs.bitPattern
                || (lhs.isZero && rhs.isZero) // any value with zero mantissa is zero
        }
    }
}



extension MedFloat16: CustomStringConvertible {
    public var description: String {
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

        let exponent = exponent
        let mantissa = mantissa

        var baseDescription = mantissa.description // TODO: sign??

        if exponent > 0 {
            baseDescription
                .append(String(repeating: "0", count: Int(exponent)))

            baseDescription
                .append(".0")
        } else if exponent == 0 {
            baseDescription
                .append(".0")
        } else { // exponent < 0
            let digitCount = baseDescription.count - (sign == .minus ? 1 : 0)

            if -exponent < digitCount {
                let dotIndex = baseDescription.index(baseDescription.endIndex, offsetBy: Int(exponent))

                baseDescription.insert(".", at: dotIndex)
            } else {
                let insertionIndex = sign == .minus
                    ? baseDescription.index(after: baseDescription.startIndex) // skipping the "-"
                    : baseDescription.startIndex

                let zeroPrefix = String(repeating: "0", count: Int(-exponent) - digitCount)
                baseDescription.insert(contentsOf: zeroPrefix, at: insertionIndex)

                baseDescription.insert(contentsOf: "0.", at: insertionIndex)
            }
        }

        return baseDescription
    }
}



extension MedFloat16: CustomDebugStringConvertible {
    public var debugDescription: String {
        description
    }
}
// TODO: can we provide custom number formatting?

// TODO: integer literal?


// TODO: comparable?

// TODO: AdditiveArithmetic? SignedNumeric protocol (aka. Numeric)
/*
 extension MedFloat16: AdditiveArithmetic {
 public static let zero = MedFloat16(bitPattern: 0) // TODO: is this true?

 public static func + (lhs: MedFloat16, rhs: MedFloat16) -> MedFloat16 {
 <#code#>
 }

 public static func - (lhs: MedFloat16, rhs: MedFloat16) -> MedFloat16 {
 <#code#>
 }
 }
 */



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



extension MedFloat16 {
    fileprivate static let maxInt4 = Int8(bitPattern: 0x7)
    fileprivate static let minInt4 = Int8(bitPattern: 0xF8)

    fileprivate static let maxInt12 = Int16(bitPattern: 0x7FF)
    fileprivate static let minInt12 = Int16(bitPattern: 0xF800)
}
