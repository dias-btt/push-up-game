//
//  AlarmTimeTests.swift
//  PushUpGameTests
//

import XCTest

@testable import PushUpGame

final class AlarmTimeTests: XCTestCase {
    func testValidBoundsAreAccepted() throws {
        let midnight = try AlarmTime(hour: 0, minute: 0)
        let lastMinute = try AlarmTime(hour: 23, minute: 59)

        XCTAssertEqual(midnight.minutesSinceMidnight, 0)
        XCTAssertEqual(lastMinute.minutesSinceMidnight, 23 * 60 + 59)
    }

    func testOutOfRangeHourIsRejected() {
        XCTAssertThrowsError(try AlarmTime(hour: 24, minute: 0)) { error in
            XCTAssertEqual(error as? AlarmValidationError, .invalidHour(24))
        }
        XCTAssertThrowsError(try AlarmTime(hour: -1, minute: 0)) { error in
            XCTAssertEqual(error as? AlarmValidationError, .invalidHour(-1))
        }
    }

    func testOutOfRangeMinuteIsRejected() {
        XCTAssertThrowsError(try AlarmTime(hour: 7, minute: 60)) { error in
            XCTAssertEqual(error as? AlarmValidationError, .invalidMinute(60))
        }
    }

    func testClampingInitKeepsValuesInRange() {
        let time = AlarmTime(clampingHour: 30, minute: -5)
        XCTAssertEqual(time.hour, 23)
        XCTAssertEqual(time.minute, 0)
    }

    func testOrderingIsByTimeOfDay() throws {
        XCTAssertLessThan(try AlarmTime(hour: 6, minute: 59), try AlarmTime(hour: 7, minute: 0))
        XCTAssertLessThan(try AlarmTime(hour: 0, minute: 1), try AlarmTime(hour: 23, minute: 0))
    }

    func testDateRoundTripPreservesWallClockTime() throws {
        let calendar = Self.calendar(timeZone: "Asia/Almaty")
        let time = try AlarmTime(hour: 6, minute: 45)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18)))

        let date = try XCTUnwrap(time.date(onSameDayAs: day, calendar: calendar))

        XCTAssertEqual(AlarmTime(date: date, calendar: calendar), time)
        XCTAssertTrue(calendar.isDate(date, inSameDayAs: day))
    }

    /// Wall-clock semantics: 07:00 stays 07:00 on both sides of a DST change,
    /// even though the absolute interval between those instants is not 24h·n.
    func testTimeIsIndependentOfDSTTransitions() throws {
        let calendar = Self.calendar(timeZone: "America/New_York")
        let time = try AlarmTime(hour: 7, minute: 0)
        let beforeDST = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7)))
        let afterDST = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9)))

        let first = try XCTUnwrap(time.date(onSameDayAs: beforeDST, calendar: calendar))
        let second = try XCTUnwrap(time.date(onSameDayAs: afterDST, calendar: calendar))

        XCTAssertEqual(AlarmTime(date: first, calendar: calendar), time)
        XCTAssertEqual(AlarmTime(date: second, calendar: calendar), time)
        XCTAssertEqual(second.timeIntervalSince(first), 47 * 3600)
    }

    private static func calendar(timeZone identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
        return calendar
    }
}
