//
//  WeekdaySetTests.swift
//  PushUpGameTests
//

import XCTest

@testable import PushUpGame

final class WeekdaySetTests: XCTestCase {
    func testEmptySetIsOneTime() {
        XCTAssertTrue(WeekdaySet().isOneTime)
        XCTAssertFalse(WeekdaySet(.monday).isOneTime)
    }

    /// The bitmask is the persisted format; changing bit assignments would
    /// silently reinterpret every stored alarm.
    func testBitAssignmentsAreStable() {
        XCTAssertEqual(WeekdaySet(.sunday).rawValue, 0b000_0001)
        XCTAssertEqual(WeekdaySet(.monday).rawValue, 0b000_0010)
        XCTAssertEqual(WeekdaySet(.saturday).rawValue, 0b100_0000)
        XCTAssertEqual(WeekdaySet.everyDay.rawValue, 0b111_1111)
        XCTAssertEqual(WeekdaySet.weekdays.rawValue, 0b011_1110)
        XCTAssertEqual(WeekdaySet.weekends.rawValue, 0b100_0001)
    }

    func testRawValueRoundTrip() throws {
        let days = WeekdaySet([.monday, .wednesday, .friday])
        XCTAssertEqual(try WeekdaySet(validatingRawValue: days.rawValue), days)
    }

    func testValidatingInitRejectsUnknownBits() {
        XCTAssertThrowsError(try WeekdaySet(validatingRawValue: 0b1000_0000)) { error in
            XCTAssertEqual(error as? AlarmValidationError, .invalidRepeatDays(rawValue: 0b1000_0000))
        }
        XCTAssertThrowsError(try WeekdaySet(validatingRawValue: -1))
    }

    func testToggleAddsAndRemoves() {
        var days = WeekdaySet()
        days.toggle(.tuesday)
        XCTAssertTrue(days.contains(.tuesday))
        days.toggle(.tuesday)
        XCTAssertTrue(days.isEmpty)
    }

    func testOrderingHonoursFirstWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2

        XCTAssertEqual(Weekday.ordered(for: calendar).first, .monday)
        XCTAssertEqual(Weekday.ordered(for: calendar).last, .sunday)

        calendar.firstWeekday = 1
        XCTAssertEqual(Weekday.ordered(for: calendar).first, .sunday)
    }

    func testSummary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2

        XCTAssertEqual(WeekdaySet().summary(calendar: calendar), "Once")
        XCTAssertEqual(WeekdaySet.everyDay.summary(calendar: calendar), "Every day")
        XCTAssertEqual(WeekdaySet.weekdays.summary(calendar: calendar), "Weekdays")
        XCTAssertEqual(WeekdaySet.weekends.summary(calendar: calendar), "Weekends")
        XCTAssertEqual(WeekdaySet([.sunday, .monday, .wednesday]).summary(calendar: calendar), "Mon, Wed, Sun")
    }
}
