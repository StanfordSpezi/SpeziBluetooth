//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import XCTest
import XCTestExtensions


final class SpeziBluetoothTests: XCTestCase {
    func testSpeziBluetooth() throws {
        let app = XCUIApplication()
        app.launch()
        
        XCTAssert(app.staticTexts["Spezi Bluetooth"].waitForExistence(timeout: 2))
    }
}
