//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
@_spi(TestingSupport)
import SpeziBluetoothServices
import XCTest
import XCTestExtensions


final class SpeziBluetoothTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()

        continueAfterFailure = false
    }

    @MainActor
    func testTestPeripheral() throws { // swiftlint:disable:this function_body_length
        let app = XCUIApplication()
        app.launch()

        XCTAssert(app.staticTexts["Spezi Bluetooth"].waitForExistence(timeout: 2))

        XCTAssert(app.buttons["Test Peripheral"].exists)
        app.buttons["Test Peripheral"].tap()

        XCTAssert(app.navigationBars.staticTexts["Nearby Devices"].waitForExistence(timeout: 2.0))
        try app.assertMinimalSimulatorInformation()

        // wait till the device is automatically connected.
        XCTAssert(app.staticTexts["TestDevice"].waitForExistence(timeout: 5.0))
        XCTAssert(app.staticTexts["connected"].waitForExistence(timeout: 10.0))
        XCTAssert(app.buttons["Pair TestDevice"].exists) // tests retrieval via ConnectedDevices

        XCTAssert(app.buttons["Test Interactions"].exists)
        app.buttons["Test Interactions"].tap()

        XCTAssert(app.navigationBars.staticTexts["Interactions"].waitForExistence(timeout: 2.0))

        XCTAssert(app.staticTexts["Manufacturer, Apple Inc."].exists)
        XCTAssert(app.staticTexts["Model"].exists) // we just check for existence of the model row

        // check that onChange registrations in configure() didn't create any unwanted retain cycles
        XCTAssert(app.staticTexts["Retain Count Check, Passed"].exists)

        // CHECK onChange behavior
        XCTAssert(app.staticTexts["Manufacturer: false, Model: true"].waitForExistence(timeout: 0.5))
        XCTAssert(app.buttons["Fetch"].exists)
        app.buttons["Fetch"].tap()
        XCTAssert(app.staticTexts["Manufacturer: true, Model: true"].waitForExistence(timeout: 0.5))

        // by checking if event row is there to verify auto notify enabled.
        XCTAssert(app.staticTexts["Event"].exists)

        // reset state
        XCTAssert(app.buttons["Reset Peripheral State"].exists)
        app.buttons["Reset Peripheral State"].tap()
        app.assert(event: "write", characteristic: .resetCharacteristic, value: "01")

        // disable events and re-enable
        #if os(macOS)
        XCTAssert(app.checkBoxes["EventLog Notifications"].exists)
        XCTAssertEqual(app.checkBoxes["EventLog Notifications"].value as? String, "1")
        app.checkBoxes["EventLog Notifications"].tap()
        XCTAssert(app.staticTexts["Notifications, Off"].waitForExistence(timeout: 2.0))

        app.checkBoxes["EventLog Notifications"].tap()
        app.assert(event: "subscribed", characteristic: .eventLogCharacteristic)
        #else

#if targetEnvironment(macCatalyst)
        let offset = 0.98
#else
        let offset = 0.93
#endif

        XCTAssert(app.switches["EventLog Notifications"].exists)
        XCTAssertEqual(app.switches["EventLog Notifications"].value as? String, "1")
        app.switches["EventLog Notifications"]
            .coordinate(withNormalizedOffset: .init(dx: offset, dy: 0.5))
            .tap()
        XCTAssert(app.staticTexts["Notifications, Off"].waitForExistence(timeout: 2.0))

        app.switches["EventLog Notifications"]
            .coordinate(withNormalizedOffset: .init(dx: offset, dy: 0.5))
            .tap()
        app.assert(event: "subscribed", characteristic: .eventLogCharacteristic)
        #endif

        // enter text we use for all validations
        try app.textFields["enter input"].enter(value: "Hello Bluetooth!")

        XCTAssert(app.buttons["Read Current String Value (R)"].waitForExistence(timeout: 2.0))
        app.buttons["Read Current String Value (R)"].tap()
        XCTAssert(app.staticTexts["Read Value, Hello World (1)"].waitForExistence(timeout: 2.0))
        app.assert(event: "read", characteristic: .readStringCharacteristic)
        XCTAssertFalse(app.staticTexts["Read value differs"].waitForExistence(timeout: 2.0)) // ensure it is consistent

        app.buttons["Read Current String Value (R)"].tap()
        XCTAssert(app.staticTexts["Read Value, Hello World (2)"].waitForExistence(timeout: 2.0))
        app.assert(event: "read", characteristic: .readStringCharacteristic)
        XCTAssertFalse(app.staticTexts["Read value differs"].waitForExistence(timeout: 2.0)) // ensure it is consistent


        XCTAssert(app.buttons["Write Input to write-only"].exists)
        app.buttons["Write Input to write-only"].tap()
        app.assert(event: "write", characteristic: .writeStringCharacteristic, value: "Hello Bluetooth!")

        XCTAssert(app.buttons["Write Input to read-write"].exists)
        app.buttons["Write Input to read-write"].tap()
        // ensure write values are saved in the property wrapper
        XCTAssert(app.staticTexts["RW Value, Hello Bluetooth!"].waitForExistence(timeout: 2.0))
        app.assert(event: "write", characteristic: .readWriteStringCharacteristic, value: "Hello Bluetooth!")

        // check if the value stays the same if we read the characteristic
        XCTAssert(app.buttons["Read Current String Value (RW)"].exists)
        app.buttons["Read Current String Value (RW)"].tap()
        XCTAssert(app.staticTexts["RW Value, Hello Bluetooth!"].waitForExistence(timeout: 2.0))
        app.assert(event: "read", characteristic: .readWriteStringCharacteristic)


        XCTAssert(app.navigationBars.buttons["Nearby Devices"].exists)
        app.navigationBars.buttons["Nearby Devices"].tap()
        try app.assertMinimalSimulatorInformation() // ensure we are back to scanning!

        XCTAssert(app.navigationBars.buttons["Spezi Bluetooth"].waitForExistence(timeout: 2.0))
        app.navigationBars.buttons["Spezi Bluetooth"].tap()

        XCTAssert(app.buttons["Test Peripheral"].waitForExistence(timeout: 2.0))
        app.buttons["Test Peripheral"].tap() // check that the device is still there if we go back

        XCTAssert(app.staticTexts["connected"].waitForExistence(timeout: 2.0))
        try app.assertMinimalSimulatorInformation() // ensure we are scanning

        // manually disconnect device and ensure it doesn't automatically reconnect to manually disconnected devices
        app.staticTexts["connected"].tap()

        XCTAssert(app.staticTexts["disconnected"].waitForExistence(timeout: 2.0))
        sleep(5)
        // check that it stays disconnected
        XCTAssert(app.staticTexts["disconnected"].waitForExistence(timeout: 2.0))
        XCTAssertFalse(app.staticTexts["Connected TestDevice"].waitForExistence(timeout: 0.5))
    }

    @MainActor
    func testPairedDevice() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssert(app.staticTexts["Spezi Bluetooth"].waitForExistence(timeout: 2))

        XCTAssert(app.buttons["Test Peripheral"].exists)
        app.buttons["Test Peripheral"].tap()

        XCTAssert(app.navigationBars.staticTexts["Nearby Devices"].waitForExistence(timeout: 2.0))
        try app.assertMinimalSimulatorInformation()

        // wait till the device is automatically connected.
        XCTAssert(app.staticTexts["TestDevice"].waitForExistence(timeout: 5.0))
        XCTAssert(app.staticTexts["connected"].waitForExistence(timeout: 10.0))

        XCTAssert(app.buttons["Pair TestDevice"].exists) // tests retrieval via ConnectedDevices
        app.buttons["Pair TestDevice"].tap()

        XCTAssert(app.navigationBars.buttons["Spezi Bluetooth"].exists)
        app.navigationBars.buttons["Spezi Bluetooth"].tap()

        XCTAssert(app.buttons["Query Count"].waitForExistence(timeout: 2.0))
        app.buttons["Query Count"].tap()
        XCTAssert(app.staticTexts["Currently initialized devices: 0"].waitForExistence(timeout: 0.5)) // ensure devices got deallocated


        XCTAssert(app.buttons["Paired Device"].exists)
        app.buttons["Paired Device"].tap()

        XCTAssert(app.staticTexts["Device, Paired"].waitForExistence(timeout: 2.0))

        XCTAssert(app.buttons["Retrieve Device"].exists)
        app.buttons["Retrieve Device"].tap()

        XCTAssert(app.staticTexts["State, disconnected"].waitForExistence(timeout: 0.5))
        XCTAssert(app.buttons["Connect Device"].exists)
        app.buttons["Connect Device"].tap()

        XCTAssert(app.staticTexts["State, connected"].waitForExistence(timeout: 10.0))
        XCTAssert(app.staticTexts["Manufacturer, Apple Inc."].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Retain Count Check, Passed"].waitForExistence(timeout: 2.0))

        XCTAssert(app.buttons["Disconnect Device"].exists)
        app.buttons["Disconnect Device"].tap()

        XCTAssert(app.staticTexts["State, disconnected"].waitForExistence(timeout: 0.5))

        XCTAssert(app.buttons["Unpair Device"].exists)
        app.buttons["Unpair Device"].tap()

        XCTAssert(app.navigationBars.buttons["Spezi Bluetooth"].exists)
        app.navigationBars.buttons["Spezi Bluetooth"].tap()

        XCTAssert(app.buttons["Query Count"].waitForExistence(timeout: 2.0))
        app.buttons["Query Count"].tap()
        XCTAssert(app.staticTexts["Currently initialized devices: 0"].waitForExistence(timeout: 0.5)) // ensure devices got deallocated
    }
}


extension XCUIApplication {
    func assertMinimalSimulatorInformation() throws {
#if targetEnvironment(simulator)
        XCTAssert(staticTexts["Scanning, No"].waitForExistence(timeout: 1.0))
        XCTAssert(staticTexts["State, unsupported"].waitForExistence(timeout: 1.0)
                  || staticTexts["State, unknown"].waitForExistence(timeout: 1.0))
        throw XCTSkip("Bluetooth tests are not supported in simulator.")
#else
        XCTAssert(staticTexts["Scanning, Yes"].waitForExistence(timeout: 5.0))
        XCTAssert(staticTexts["State, poweredOn"].exists)
#endif
    }

    func assert(event: String, characteristic: BTUUID, value: String? = nil) {
        XCTAssert(staticTexts["Event, \(event)"].waitForExistence(timeout: 5.0))
        XCTAssert(staticTexts["Characteristic, \(BTUUID.toCustomShort(characteristic))"].waitForExistence(timeout: 2.0))
        if let value {
            XCTAssert(staticTexts["Value, \(value)"].waitForExistence(timeout: 2.0))
        }
    }
}
