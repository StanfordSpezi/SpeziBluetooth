//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import SpeziBluetooth


@_spi(TestingSupport)
public struct TestService: BluetoothService, Sendable {
    public static let id: BTUUID = .testService

    @Characteristic(id: .eventLogCharacteristic, notify: true)
    public var eventLog: EventLog?


    @Characteristic(id: .readStringCharacteristic)
    public var readString: String?

    @Characteristic(id: .writeStringCharacteristic)
    public var writeString: String?

    @Characteristic(id: .readWriteStringCharacteristic)
    public var readWriteString: String?

    @Characteristic(id: .resetCharacteristic)
    public var reset: Bool? // swiftlint:disable:this discouraged_optional_boolean

    public init() {}
}
