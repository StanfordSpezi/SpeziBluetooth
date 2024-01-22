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

        XCTAssert(app.buttons["Nearby Devices"].exists)
        XCTAssert(app.buttons["Auto Connect Device"].exists)

        app.buttons["Nearby Devices"].tap()

        XCTAssert(app.navigationBars.staticTexts["Nearby Devices"].waitForExistence(timeout: 2.0))
        assertMinimalSimulatorInformation(app)

        XCTAssert(app.navigationBars.buttons["Spezi Bluetooth"].exists)
        app.navigationBars.buttons["Spezi Bluetooth"].tap()

        XCTAssert(app.buttons["Auto Connect Device"].waitForExistence(timeout: 2.0))
        app.buttons["Auto Connect Device"].tap()

        XCTAssert(app.navigationBars.staticTexts["Auto Connect Device"].waitForExistence(timeout: 2.0))
        assertMinimalSimulatorInformation(app)

        XCTAssert(app.navigationBars.buttons["Spezi Bluetooth"].exists)
        app.navigationBars.buttons["Spezi Bluetooth"].tap()
    }

    private func assertMinimalSimulatorInformation(_ app: XCUIApplication) {
        XCTAssert(app.staticTexts["Scanning, No"].exists)
        XCTAssert(app.staticTexts["State, unsupported"].exists)
        XCTAssert(app.staticTexts["Searching for nearby devices ..."].exists)
    }
}
