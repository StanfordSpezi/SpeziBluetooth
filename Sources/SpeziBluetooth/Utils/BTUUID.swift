//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// A universally unique identifier, as defined by Bluetooth standards.
///
/// The `BTUUID` type mirrors the functionality of the [`CBUUID`](https://developer.apple.com/documentation/corebluetooth/cbuuid)
/// class of CoreBluetooth. However, `BTUUID` is [`Sendable`](https://developer.apple.com/documentation/swift/sendable).
/// `CBUUID` is by its definition not `Sendable`. Not because of its implementation not-being thread-safe, but it being declared as an open class with the open properties
/// ``uuidString`` and ``data``. By wrapping the `CBUUID` type, and making sure no-one can inject a non-thread-safe sub-class, we create a effectively sendable version
/// of `CBUUID`.
public struct BTUUID {
    /// The CoreBluetooth UUID.
    public nonisolated(unsafe) let cbuuid: CBUUID

    /// The UUID represented as a string.
    public var uuidString: String {
        cbuuid.uuidString
    }

    /// The data of the UUID.
    public var data: Data {
        cbuuid.data
    }


    /// Create a Bluetooth UUID from a 16-, 32-, or 128-bit UUID string.
    /// - Parameter string: A string containing a 16-, 32-, or 128-bit UUID.
    public init(string: String) {
        self.cbuuid = CBUUID(string: string)
    }

    /// Create a Bluetooth UUID from a 16-, 32-, or 128-bit UUID data container.
    /// - Parameter data: Data containing a 16-, 32-, or 128-bit UUID.
    public init(data: Data) {
        self.cbuuid = CBUUID(data: data)
    }

    /// Create a Bluetooth UUID from a UUID.
    /// - Parameter nsuuid: The uuid.
    public init(nsuuid: UUID) {
        self.cbuuid = CBUUID(nsuuid: nsuuid)
    }

    /// Create a Bluetooth UUID from a CoreBluetooth UUID.
    /// - Parameter uuid: The CoreBluetooth UUID.
    public init(from uuid: CBUUID) {
        self.cbuuid = CBUUID(data: uuid.data) // this makes sure we do not accidentally inject a subclass
    }
}


extension BTUUID: Sendable {}


extension BTUUID: ExpressibleByStringLiteral {
    /// Create a Bluetooth UUID from a 16-, 32-, or 128-bit UUID string.
    /// - Parameter stringLiteral: A string containing a 16-, 32-, or 128-bit UUID.
    public init(stringLiteral value: StringLiteralType) {
        self.init(string: value)
    }
}


extension BTUUID: Hashable {}


extension BTUUID: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        cbuuid.description
    }

    public var debugDescription: String {
        cbuuid.debugDescription
    }
}


extension CBUUID {
    convenience init(from btuuid: BTUUID) {
        self.init(data: btuuid.data)
    }
}
