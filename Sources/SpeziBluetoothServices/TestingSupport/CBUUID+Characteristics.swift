//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth


@_spi(TestingSupport)
extension BTUUID {
    private static let prefix = "0000"
    private static let suffix = "-0000-1000-8000-00805F9B34FB"

    /// The test service.
    public static var testService: BTUUID {
        .uuid(ofCustom: "F001")
    }

    /// An event log of events of the test peripheral implementation.
    public static var eventLogCharacteristic: BTUUID {
        .uuid(ofCustom: "F002")
    }
    /// A string characteristic that you can read.
    public static var readStringCharacteristic: BTUUID {
        .uuid(ofCustom: "F003")
    }
    /// A string characteristic that you can write.
    public static var writeStringCharacteristic: BTUUID {
        .uuid(ofCustom: "F004")
    }
    /// A string characteristic that you can read and write.
    public static var readWriteStringCharacteristic: BTUUID {
        .uuid(ofCustom: "F005")
    }
    /// Reset peripheral state to default settings.
    public static var resetCharacteristic: BTUUID {
        .uuid(ofCustom: "F006")
    }


    private static func uuid(ofCustom: String) -> BTUUID {
        precondition(ofCustom.count == 4, "Unexpected length of \(ofCustom.count)")
        return BTUUID(string: "\(prefix)\(ofCustom)\(suffix)")
    }

    /// Get a short uuid representation of your custom uuid base.
    /// - Parameter uuid: The uuid with the SpeziBluetooth base id.
    /// - Returns: Short uuid format.
    public static func toCustomShort(_ uuid: BTUUID) -> String {
        var string = uuid.uuidString
        assert(string.hasPrefix(prefix), "unexpected uuid format")
        assert(string.hasSuffix(suffix), "unexpected uuid format")
        string.removeFirst(prefix.count)
        string.removeLast(suffix.count)
        assert(string.count == 4, "unexpected uuid string length")
        return string
    }
}
