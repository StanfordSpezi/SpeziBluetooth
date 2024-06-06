//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
@testable import BluetoothServices
import CoreBluetooth
import NIO
@_spi(TestingSupport)
@testable import SpeziBluetooth
import XCTByteCoding
import XCTest


final class DeviceInformationTests: XCTestCase {
    func testPnPID() throws {
        try testIdentity(from: VendorIDSource.bluetoothSIGAssigned)
        try testIdentity(from: VendorIDSource.usbImplementersForumAssigned)
        try testIdentity(from: VendorIDSource.reserved(23))

        try testIdentity(from: PnPID(vendorIdSource: .bluetoothSIGAssigned, vendorId: 24, productId: 1, productVersion: 56))
    }
}
