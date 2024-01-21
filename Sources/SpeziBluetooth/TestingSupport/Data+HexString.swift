//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Data {
    /// Create `Data` from a hex string.
    ///
    /// The hex string may be prefixed with `"0x"` or `"0X"`.
    /// - Parameter hex: The hex string.
    @_spi(TestingSupport)
    public init?(hex: String) {
        // while this seems complicated, and you can do it with shorter code,
        // this doesn't incur any heap allocations for string. Pretty neat.

        var index = hex.startIndex

        let hexCount: Int

        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            index = hex.index(index, offsetBy: 2)
            hexCount = hex.count - 2
        } else {
            hexCount = hex.count
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(hexCount / 2 + hexCount % 2)

        if !hexCount.isMultiple(of: 2) {
            guard let byte = UInt8(String(hex[index]), radix: 16) else {
                return nil
            }
            bytes.append(byte)

            index = hex.index(after: index)
        }


        while index < hex.endIndex {
            guard let byte = UInt8(hex[index ... hex.index(after: index)], radix: 16) else {
                return nil
            }
            bytes.append(byte)

            index = hex.index(index, offsetBy: 2)
        }

        guard hexCount / bytes.count == 2 else {
            return nil
        }
        self.init(bytes)
    }
}
