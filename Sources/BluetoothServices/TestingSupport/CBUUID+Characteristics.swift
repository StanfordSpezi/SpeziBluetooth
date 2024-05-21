//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


@_spi(TestingSupport)
extension CBUUID {
    private static let prefix = "0000"
    private static let suffix = "-0000-1000-8000-00805F9B34FB"

    /// The test service.
    public static let testService: CBUUID = .uuid(ofCustom: "F001")

    /// An event log of events of the test peripheral implementation.
    public static let eventLogCharacteristic: CBUUID = .uuid(ofCustom: "F002")
    /// A string characteristic that you can read.
    public static let readStringCharacteristic: CBUUID = .uuid(ofCustom: "F003")
    /// A string characteristic that you can write.
    public static let writeStringCharacteristic: CBUUID = .uuid(ofCustom: "F004")
    /// A string characteristic that you can read and write.
    public static nonisolated(unsafe) let readWriteStringCharacteristic: CBUUID = .uuid(ofCustom: "F005")
    /// Reset peripheral state to default settings.
    public static nonisolated(unsafe) let resetCharacteristic: CBUUID = .uuid(ofCustom: "F006")


    private static func uuid(ofCustom: String) -> CBUUID {
        precondition(ofCustom.count == 4, "Unexpected length of \(ofCustom.count)")
        return CBUUID(string: "\(prefix)\(ofCustom)\(suffix)")
    }

    /// Get a short uuid representation of your custom uuid base.
    /// - Parameter uuid: The uuid with the SpeziBluetooth base id.
    /// - Returns: Short uuid format.
    public static func toCustomShort(_ uuid: CBUUID) -> String {
        var string = uuid.uuidString
        assert(string.hasPrefix(prefix), "unexpected uuid format")
        assert(string.hasSuffix(suffix), "unexpected uuid format")
        string.removeFirst(prefix.count)
        string.removeLast(suffix.count)
        assert(string.count == 4, "unexpected uuid string length")
        return string
    }
}
