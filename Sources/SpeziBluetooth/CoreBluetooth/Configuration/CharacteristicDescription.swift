//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import class CoreBluetooth.CBUUID


/// A characteristic description.
public struct CharacteristicDescription: Sendable {
    /// The characteristic id.
    public let characteristicId: CBUUID
    /// Flag indicating if descriptors should be discovered for this characteristic.
    public let discoverDescriptors: Bool


    /// Create a new characteristic description.
    /// - Parameters:
    ///   - id: The bluetooth characteristic id.
    ///   - discoverDescriptors: Optional flag to specify that descriptors of this characteristic should be discovered.
    public init(id: CBUUID, discoverDescriptors: Bool = false) {
        self.characteristicId = id
        self.discoverDescriptors = discoverDescriptors
    }
}


extension CharacteristicDescription: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(id: CBUUID(string: value))
    }
}


extension CharacteristicDescription: Hashable {
    public static func == (lhs: CharacteristicDescription, rhs: CharacteristicDescription) -> Bool {
        lhs.characteristicId == rhs.characteristicId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(characteristicId)
    }
}
