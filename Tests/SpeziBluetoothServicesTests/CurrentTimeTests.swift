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


@Suite("Current Time Service")
struct CurrentTimeTests {
    static var nowTestTime: ExactTime256 {
        let dateTime = DateTime(year: 2024, month: .june, day: 6, hours: 12, minutes: 4, seconds: 44)
        let dayDateTime = DayDateTime(dateTime: dateTime, dayOfWeek: .thursday)
        return ExactTime256(dayDateTime: dayDateTime, fractions256: 128)
    }

    @Test("Synchronize Device Time")
    func testSynchronizeTimeNoTime() async throws {
        let service = CurrentTimeService()
        let now = Self.nowTestTime

        try await confirmation { confirmation in
            service.$currentTime.onWrite { time, _ in
                #expect(time == CurrentTime(time: now))
                confirmation()

                throw CBATTError(try #require(.init(rawValue: 0x80)))
            }

            let date = try #require(now.date)
            try await service.synchronizeDeviceTime(now: date)
        }
    }

    @Test("Synchronize Device Time with difference")
    func testSynchronizeTimeBasedOnDifference() async throws {
        let service = CurrentTimeService()
        let now = Self.nowTestTime

        let deviceTime = ExactTime256(from: try #require(now.date).addingTimeInterval(-10))
        service.$currentTime.inject(CurrentTime(time: deviceTime, adjustReason: .manualTimeUpdate))

        try await confirmation { confirmation in
            service.$currentTime.onWrite { time, _ in
                #expect(time == CurrentTime(time: now))
                confirmation()
            }

            let date = try #require(now.date)
            try await service.synchronizeDeviceTime(now: date, threshold: .seconds(8))
        }
    }

    @Test("Synchronize Device Time Identical")
    func testSynchronizeTimeNoDifference() async throws {
        let service = CurrentTimeService()
        let now = Self.nowTestTime

        service.$currentTime.inject(CurrentTime(time: now, adjustReason: .manualTimeUpdate))

        try await confirmation(expectedCount: 0) { confirmation in
            service.$currentTime.onWrite { time, _ in
                #expect(time == CurrentTime(time: now))
                confirmation()
            }

            let date = try #require(now.date)
            try await service.synchronizeDeviceTime(now: date)
        }
    }

    @Test("DateTime")
    func testDateTime() throws {
        try testIdentity(from: DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40))
        try testIdentity(from: DateTime(hours: 23, minutes: 50, seconds: 40))
    }

    @Test("DayOfWeek")
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

    @Test("DayOfWeek Description")
    func testDayOfWeekStrings() throws {
        let expected = ["unknown", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "DayOfWeek(rawValue: 26)"]
        let values = [DayOfWeek.unknown, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday, DayOfWeek(rawValue: 26)]
        #expect(values.map { $0.description } == expected)
    }

    @Test("DateTime.Month Description")
    func testMonthStrings() throws {
        // swiftlint:disable line_length
        let expected = ["unknown", "january", "february", "march", "april", "mai", "june", "july", "august", "september", "october", "november", "december", "Month(rawValue: 23)"]
        let values = [DateTime.Month.unknown, .january, .february, .march, .april, .mai, .june, .july, .august, .september, .october, .november, .december, .init(rawValue: 23)]
        // swiftlint:enable line_length
        #expect(values.map { $0.description } == expected)
    }

    @Test("DayDateTime")
    func testDayDateTime() throws {
        let dateTime = DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40)
        try testIdentity(from: DayDateTime(dateTime: dateTime, dayOfWeek: .tuesday))
    }

    @Test("ExactTime256")
    func testExactTime256() throws {
        let dateTime = DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40)
        let dayDateTime = DayDateTime(dateTime: dateTime, dayOfWeek: .wednesday)
        try testIdentity(from: ExactTime256(dayDateTime: dayDateTime, fractions256: 127))
    }

    @Test("CurrentTime")
    func testCurrentTime() throws {
        let dateTime = DateTime(year: 2005, month: .december, day: 27, hours: 12, minutes: 31, seconds: 40)
        let dayDateTime = DayDateTime(dateTime: dateTime, dayOfWeek: .wednesday)
        let exactTime = ExactTime256(dayDateTime: dayDateTime, fractions256: 127)
        try testIdentity(from: CurrentTime(time: exactTime))
        try testIdentity(from: CurrentTime(time: exactTime, adjustReason: .manualTimeUpdate))
        try testIdentity(from: CurrentTime(time: exactTime, adjustReason: [.manualTimeUpdate, .changeOfTimeZone]))
    }

    @Test("CurrentTime.AdjustReason Codable")
    func testCurrentTimeCodable() throws {
        // test that we are coding from a single value container
        let encoded = try JSONEncoder().encode(UInt8(0x01))
        let reason = try JSONDecoder().decode(CurrentTime.AdjustReason.self, from: encoded)
        #expect(reason == .manualTimeUpdate)

        let encodedReason = try JSONEncoder().encode(CurrentTime.AdjustReason.manualTimeUpdate)
        let rawValue = try JSONDecoder().decode(UInt8.self, from: encodedReason)
        #expect(rawValue == 0x01)
    }

    @Test("Foundation Date Conversions")
    func testDateConversions() throws {
        let baseNanoSeconds = Int(255 * (1.0 / 256.0) * 1000_000_000)
        var components = DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26)
        components.nanosecond = baseNanoSeconds + 1231234
        components.weekday = 6

        let date = try #require(Calendar.current.date(from: components))

        let exactTime = try #require(ExactTime256(from: components))
        #expect(exactTime.year == 2024)
        #expect(exactTime.month == .mai)
        #expect(exactTime.day == 17)
        #expect(exactTime.hours == 16)
        #expect(exactTime.minutes == 11)
        #expect(exactTime.seconds == 26)
        #expect(exactTime.dayOfWeek == .friday)
        #expect(exactTime.fractions256 == 255)

        // test Date initializers
        let time0 = ExactTime256(from: date)
        #expect(time0 == exactTime)
        let time1 = DayDateTime(from: date)
        #expect(time1 == exactTime.dayDateTime)
        let time2 = DateTime(from: date)
        #expect(time2 == exactTime.dateTime)


        #expect(
            exactTime.dateComponents ==
            DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26, nanosecond: baseNanoSeconds, weekday: 6)
        )
        #expect(
            exactTime.dayDateTime.dateComponents ==
            DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26, weekday: 6)
        )
        #expect(exactTime.dateTime.dateComponents == DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26))
    }

    @Test("Nanoseconds Overflow")
    func testNanoSecondsOverflow() throws {
        var components = DateComponents(year: 2024, month: 5, day: 17, hour: 16, minute: 11, second: 26)
        components.nanosecond = Int((256.0 + 17.0) * (1.0 / 256.0) * 1000_000_000)

        let exactTime = try #require(ExactTime256(from: components))
        #expect(exactTime.seconds == 27)
        #expect(exactTime.fractions256 == 17)
    }

    @Test("CurrentTime.AdjustReason Description")
    func testAdjustReasonStrings() {
        let reasons: CurrentTime.AdjustReason = [.manualTimeUpdate, .externalReferenceTimeUpdate, .changeOfTimeZone, .changeOfDST]
        #expect(reasons.description == "[manualTimeUpdate, externalReferenceTimeUpdate, changeOfTimeZone, changeOfDST]")
        #expect(reasons.debugDescription == "AdjustReason(rawValue: 0x0F)")
    }
}
