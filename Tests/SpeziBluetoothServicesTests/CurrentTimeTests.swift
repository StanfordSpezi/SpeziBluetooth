//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import NIO
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import XCTByteCoding
import XCTest


final class CurrentTimeTests: XCTestCase {
    static var nowTestTime: ExactTime256 {
        let dateTime = DateTime(year: 2024, month: .june, day: 6, hours: 12, minutes: 4, seconds: 44)
        let dayDateTime = DayDateTime(dateTime: dateTime, dayOfWeek: .thursday)
        return ExactTime256(dayDateTime: dayDateTime, fractions256: 128)
    }

    func testSynchronizeTimeNoTime() async throws {
        let service = CurrentTimeService()
        let now = Self.nowTestTime

        let writeExpectation = XCTestExpectation(description: "Write Expectation")
        service.$currentTime.onWrite { time, _ in
            XCTAssertEqual(time, CurrentTime(time: now))
            writeExpectation.fulfill()

            throw CBATTError(try XCTUnwrap(.init(rawValue: 0x80)))
        }

        let date = try XCTUnwrap(now.date)
        service.synchronizeDeviceTime(now: date)

        await fulfillment(of: [writeExpectation])
        try await Task.sleep(for: .milliseconds(500)) // let task complete
    }

    func testSynchronizeTimeBasedOnDifference() async throws {
        let service = CurrentTimeService()
        let now = Self.nowTestTime

        let deviceTime = ExactTime256(from: try XCTUnwrap(now.date).addingTimeInterval(-10))
        service.$currentTime.inject(CurrentTime(time: deviceTime, adjustReason: .manualTimeUpdate))

        let writeExpectation = XCTestExpectation(description: "Write Expectation")
        service.$currentTime.onWrite { time, _ in
            XCTAssertEqual(time, CurrentTime(time: now))
            writeExpectation.fulfill()
        }

        let date = try XCTUnwrap(now.date)
        service.synchronizeDeviceTime(now: date, threshold: .seconds(8))

        await fulfillment(of: [writeExpectation])
        try await Task.sleep(for: .milliseconds(500)) // let task complete
    }

    func testSynchronizeTimeNoDifference() async throws {
        let service = CurrentTimeService()
        let now = Self.nowTestTime

        service.$currentTime.inject(CurrentTime(time: now, adjustReason: .manualTimeUpdate))

        let writeExpectation = XCTestExpectation(description: "Write Expectation")
        writeExpectation.isInverted = true

        service.$currentTime.onWrite { time, _ in
            XCTAssertEqual(time, CurrentTime(time: now))
            writeExpectation.fulfill()
        }

        let date = try XCTUnwrap(now.date)
        service.synchronizeDeviceTime(now: date)

        await fulfillment(of: [writeExpectation], timeout: 1)
        try await Task.sleep(for: .milliseconds(500)) // let task complete
    }

    func testDateTime() throws {
        try testIdentity(from: DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40))
        try testIdentity(from: DateTime(hours: 23, minutes: 50, seconds: 40))
    }

    func testDayOfWeek() throws {
        try testIdentity(from: DayOfWeek.unknown)
        try testIdentity(from: DayOfWeek.monday)
        try testIdentity(from: DayOfWeek.tuesday)
        try testIdentity(from: DayOfWeek.wednesday)
        try testIdentity(from: DayOfWeek.thursday)
        try testIdentity(from: DayOfWeek.friday)
        try testIdentity(from: DayOfWeek.saturday)
        try testIdentity(from: DayOfWeek.sunday)
        try testIdentity(from: DayOfWeek(rawValue: 26)) // test a reserved value
    }

    func testDayDateTime() throws {
        let dateTime = DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40)
        try testIdentity(from: DayDateTime(dateTime: dateTime, dayOfWeek: .tuesday))
    }

    func testExactTime256() throws {
        let dateTime = DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40)
        let dayDateTime = DayDateTime(dateTime: dateTime, dayOfWeek: .wednesday)
        try testIdentity(from: ExactTime256(dayDateTime: dayDateTime, fractions256: 127))
    }

    func testCurrentTime() throws {
        let dateTime = DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40)
        let dayDateTime = DayDateTime(dateTime: dateTime, dayOfWeek: .wednesday)
        let exactTime = ExactTime256(dayDateTime: dayDateTime, fractions256: 127)
        try testIdentity(from: CurrentTime(time: exactTime))
        try testIdentity(from: CurrentTime(time: exactTime, adjustReason: .manualTimeUpdate))
        try testIdentity(from: CurrentTime(time: exactTime, adjustReason: [.manualTimeUpdate, .changeOfTimeZone]))
    }

    func testCurrentTimeCodable() throws {
        // test that we are coding from a single value container
        let encoded = try JSONEncoder().encode(UInt8(0x01))
        let reason = try JSONDecoder().decode(CurrentTime.AdjustReason.self, from: encoded)
        XCTAssertEqual(reason, .manualTimeUpdate)

        let encodedReason = try JSONEncoder().encode(CurrentTime.AdjustReason.manualTimeUpdate)
        let rawValue = try JSONDecoder().decode(UInt8.self, from: encodedReason)
        XCTAssertEqual(rawValue, 0x01)
    }

    func testDateConversions() throws {
        let baseNanoSeconds = Int(255 * (1.0 / 256.0) * 1000_000_000)
        var components = DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26)
        components.nanosecond = baseNanoSeconds + 1231234
        components.weekday = 6

        let date = try XCTUnwrap(Calendar.current.date(from: components))

        let exactTime = try XCTUnwrap(ExactTime256(from: components))
        XCTAssertEqual(exactTime.year, 2024)
        XCTAssertEqual(exactTime.month, .mai)
        XCTAssertEqual(exactTime.day, 17)
        XCTAssertEqual(exactTime.hours, 16)
        XCTAssertEqual(exactTime.minutes, 11)
        XCTAssertEqual(exactTime.seconds, 26)
        XCTAssertEqual(exactTime.dayOfWeek, .friday)
        XCTAssertEqual(exactTime.fractions256, 255)

        // test Date initializers
        let time0 = ExactTime256(from: date)
        XCTAssertEqual(time0, exactTime)
        let time1 = DayDateTime(from: date)
        XCTAssertEqual(time1, exactTime.dayDateTime)
        let time2 = DateTime(from: date)
        XCTAssertEqual(time2, exactTime.dateTime)


        XCTAssertEqual(
            exactTime.dateComponents,
            DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26, nanosecond: baseNanoSeconds, weekday: 6)
        )
        XCTAssertEqual(
            exactTime.dayDateTime.dateComponents,
            DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26, weekday: 6)
        )
        XCTAssertEqual(exactTime.dateTime.dateComponents, DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26))
    }

    func testNanoSecondsOverflow() throws {
        var components = DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26)
        components.nanosecond = Int((256.0 + 17.0) * (1.0 / 256.0) * 1000_000_000)

        let exactTime = try XCTUnwrap(ExactTime256(from: components))
        XCTAssertEqual(exactTime.seconds, 27)
        XCTAssertEqual(exactTime.fractions256, 17)
    }
}
