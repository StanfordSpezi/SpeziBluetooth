//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import XCTest
import XCTestExtensions


// TODO: last manually connected doesn't work! (longer timeout when removing disconnected devices!)
//  => resolved?
// TODO: how to we test remote disconnects? => characteristic stopping advertising for a few seconds?
// => // TODO: https://stackoverflow.com/questions/51576340/corebluetooth-stopadvertising-does-not-stop
//        // => remove all services?

// TODO: test returning an error as well?

final class SpeziBluetoothTests: XCTestCase {
    func testTestPeripheral() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssert(app.staticTexts["Spezi Bluetooth"].waitForExistence(timeout: 2))

        XCTAssert(app.buttons["Test Peripheral"].exists)
        app.buttons["Test Peripheral"].tap()

        assertMinimalSimulatorInformation(app)

        // TODO: assert device names? (this worked once?) check with local name?
        // TODO: assert connecting

        // TODO: assert connected

        XCTAssert(app.buttons["Test Interactions"].exists)
        app.buttons["Test Interactions"].tap()

        XCTAssert(app.navigationBars.staticTexts["Interactions"].waitForExistence(timeout: 2.0))

        // TODO: assert device information.

        // TODO: check "Event" exists (notifications is enabled)!

        // TODO: toggle notifications of + assert notifications off
        // TODO: toggle notifications on + assert event log

        // TODO: enter input + dismiss keyboard (input should be random!)

        // TODO: read current string value + assert increment??? + assert equal (non existent of warning!)
        // TODO: assert event


        // TODO: write to write-only (assert event)

        // TODO: write input value to RW + assert value
        // TODO: assert event
        // TODO: read RW + assert value
        // TODO: assert event


        // TODO: navigate back
        // TODO: navigate home screen and back to nearby devices + assert that device is still connected!
        // TODO: tap disconnect + and wait 5s that it doesn't automatically connect again!
    }

    func testSpeziBluetooth() throws {
        // TODO: just test nearby devices here!
        let app = XCUIApplication()
        app.launch()
        
        XCTAssert(app.staticTexts["Spezi Bluetooth"].waitForExistence(timeout: 2))

        XCTAssert(app.buttons["Nearby Devices"].exists)
        XCTAssert(app.buttons["Test Peripheral"].exists)

        app.buttons["Nearby Devices"].tap()

        XCTAssert(app.navigationBars.staticTexts["Nearby Devices"].waitForExistence(timeout: 2.0))
        assertMinimalSimulatorInformation(app)

        XCTAssert(app.navigationBars.buttons["Spezi Bluetooth"].exists)
        app.navigationBars.buttons["Spezi Bluetooth"].tap()

        XCTAssert(app.buttons["Test Peripheral"].waitForExistence(timeout: 2.0))
        app.buttons["Test Peripheral"].tap()

        XCTAssert(app.navigationBars.staticTexts["Nearby Devices"].waitForExistence(timeout: 2.0))
        assertMinimalSimulatorInformation(app)

        XCTAssert(app.navigationBars.buttons["Spezi Bluetooth"].exists)
        app.navigationBars.buttons["Spezi Bluetooth"].tap()
    }

    private func assertMinimalSimulatorInformation(_ app: XCUIApplication) {
        #if targetEnvironment(simulator)
        XCTAssert(app.staticTexts["Scanning, No"].exists)
        XCTAssert(app.staticTexts["State, unsupported"].exists)
        XCTAssert(app.staticTexts["Searching for nearby devices ..."].exists)
        #else
        XCTAssert(app.staticTexts["Scanning, Yes"].exists)
        XCTAssert(app.staticTexts["State, poweredOn"].exists)
        #endif
    }
}
