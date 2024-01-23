//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import NIO


extension Float32: ByteCodable {
    /// Decodes a float from its byte representation.
    ///
    /// Decodes a `Float32` from a `ByteBuffer`.
    ///
    /// This covers the `float32` type of Bluetooth.
    ///
    /// - Note: For reference, the basic types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Volume 1, Part E, 3.9.1 Basic types.
    /// - Parameter byteBuffer: The bytebuffer to decode from.
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let bitPattern = UInt32(from: &byteBuffer) else {
            return nil
        }

        self.init(bitPattern: bitPattern)
    }

    /// Encodes a float to its byte representation.
    ///
    /// Encodes a `Float32` into a `ByteBuffer`.
    ///
    /// This covers the `float32` type of Bluetooth.
    ///
    /// - Note: For reference, the basic types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Volume 1, Part E, 3.9.1 Basic types.
    /// - Parameter byteBuffer: The bytebuffer to decode to.
    public func encode(to byteBuffer: inout ByteBuffer) {
        bitPattern.encode(to: &byteBuffer)
    }
}


extension Float64: ByteCodable {
    /// Decodes a float from its byte representation.
    ///
    /// Decodes a `Float64` from a `ByteBuffer`.
    ///
    /// This covers the `float64` type of Bluetooth.
    ///
    /// - Note: For reference, the basic types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Volume 1, Part E, 3.9.1 Basic types.
    /// - Parameter byteBuffer: The bytebuffer to decode from.
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let bitPattern = UInt64(from: &byteBuffer) else {
            return nil
        }

        self.init(bitPattern: bitPattern)
    }

    /// Encodes a float to its byte representation.
    ///
    /// Encodes a `Float64` into a `ByteBuffer`.
    ///
    /// This covers the `float64` type of Bluetooth.
    ///
    /// - Note: For reference, the basic types in Bluetooth are illustrated in
    ///     Bluetooth Core Specification, Volume 1, Part E, 3.9.1 Basic types.
    /// - Parameter byteBuffer: The bytebuffer to decode to.
    public func encode(to byteBuffer: inout ByteBuffer) {
        bitPattern.encode(to: &byteBuffer)
    }
}
