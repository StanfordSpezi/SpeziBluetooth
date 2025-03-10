//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCodingTesting
import CoreBluetooth
import NIOCore
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import Testing


@Suite("DeviceInformation Service")
struct DeviceInformationTests {
    @Test("PnPID")
    func testPnPID() throws {
        try testIdentity(from: VendorIDSource.bluetoothSIGAssigned)
        try testIdentity(from: VendorIDSource.usbImplementersForumAssigned)
        try testIdentity(from: VendorIDSource.reserved(23))

        try testIdentity(from: PnPID(vendorIdSource: .bluetoothSIGAssigned, vendorId: 24, productId: 1, productVersion: 56))
    }
}
