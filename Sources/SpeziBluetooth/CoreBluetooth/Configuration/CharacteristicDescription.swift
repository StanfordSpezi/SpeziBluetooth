//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// A characteristic description.
public struct CharacteristicDescription {
    /// The characteristic id.
    public let characteristicId: BTUUID
    /// Flag indicating if descriptors should be discovered for this characteristic.
    public let discoverDescriptors: Bool
    /// Flag indicating if SpeziBluetooth should automatically read the initial value from the peripheral.
    public let autoRead: Bool


    /// Create a new characteristic description.
    /// - Parameters:
    ///   - id: The bluetooth characteristic id.
    ///   - discoverDescriptors: Optional flag to specify that descriptors of this characteristic should be discovered.
    ///   - autoRead: Flag indicating if SpeziBluetooth should automatically read the initial value from the peripheral.
    public init(id: BTUUID, discoverDescriptors: Bool = false, autoRead: Bool = true) {
        self.characteristicId = id
        self.discoverDescriptors = discoverDescriptors
        self.autoRead = autoRead
    }
}


extension CharacteristicDescription: Sendable {}


extension CharacteristicDescription: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(id: BTUUID(stringLiteral: value))
    }
}


extension CharacteristicDescription: Hashable {}
