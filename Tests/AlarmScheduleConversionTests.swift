//
//  AlarmScheduleConversionTests.swift
//  PushUpGameTests
//

import AlarmKit
import XCTest

@testable import PushUpGame

/// Conversion between app schedules and AlarmKit schedules, plus the
/// time-zone/DST behaviour the sync rules depend on. Only constructs AlarmKit
/// value types; never schedules a real alarm.
final class AlarmScheduleConversionTests: XCTestCase {
    func testOneTimeAlarmUsesRelativeScheduleWithNeverRecurrence() throws {
        let schedule = AlarmSchedule(time: try AlarmTime(hour: 6, minute: 30), weekdays: [])

        let expected = Alarm.Schedule.relative(
            .init(time: .init(hour: 6, minute: 30), repeats: .never)
        )
        XCTAssertEqual(AlarmKitService.alarmKitSchedule(from: schedule), expected)
    }

    func testRecurringAlarmUsesWeeklyRecurrenceInStableOrder() throws {
        let schedule = AlarmSchedule(
            time: try AlarmTime(hour: 7, minute: 5),
            weekdays: WeekdaySet([.friday, .monday, .sunday])
        )

        let expected = Alarm.Schedule.relative(
            .init(time: .init(hour: 7, minute: 5), repeats: .weekly([.sunday, .monday, .friday]))
        )
        XCTAssertEqual(AlarmKitService.alarmKitSchedule(from: schedule), expected)
    }

    func testEveryWeekdayMapsToAllSevenLocaleWeekdays() throws {
        let schedule = AlarmSchedule(time: .wakeUpDefault, weekdays: .everyDay)
        XCTAssertEqual(
            schedule.localeWeekdays,
            [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        )
    }

    func testRoundTripThroughAlarmKitSchedule() throws {
        let schedules = [
            AlarmSchedule(time: try AlarmTime(hour: 0, minute: 0), weekdays: []),
            AlarmSchedule(time: try AlarmTime(hour: 23, minute: 59), weekdays: .weekdays),
            AlarmSchedule(time: try AlarmTime(hour: 12, minute: 15), weekdays: .weekends),
        ]
        for schedule in schedules {
            let converted = AlarmKitService.alarmKitSchedule(from: schedule)
            XCTAssertEqual(AlarmKitService.appSchedule(from: converted), schedule)
        }
    }

    func testWeeklyOrderFromSystemDoesNotAffectEquality() throws {
        let system = Alarm.Schedule.relative(
            .init(time: .init(hour: 8, minute: 0), repeats: .weekly([.friday, .monday]))
        )
        XCTAssertEqual(
            AlarmKitService.appSchedule(from: system),
            AlarmSchedule(time: try AlarmTime(hour: 8, minute: 0), weekdays: WeekdaySet([.monday, .friday]))
        )
    }

    func testUnsupportedSystemSchedulesAreNotRecognised() {
        XCTAssertNil(AlarmKitService.appSchedule(from: nil))
        XCTAssertNil(AlarmKitService.appSchedule(from: .fixed(Date(timeIntervalSince1970: 0))))
    }

    func testAuthorizationMapping() {
        XCTAssertEqual(AlarmKitService.authorization(from: .authorized), .authorized)
        XCTAssertEqual(AlarmKitService.authorization(from: .denied), .denied)
        XCTAssertEqual(AlarmKitService.authorization(from: .notDetermined), .notDetermined)
    }

    // MARK: - Fire-date logic used to detect expired one-time alarms

    func testOneTimeFireDateIsLaterSameDayWhenTimeIsAhead() throws {
        let calendar = Self.calendar("Asia/Almaty")
        let armedAt = try Self.date(2026, 11, 18, 6, 0, calendar)
        let schedule = AlarmSchedule(time: try AlarmTime(hour: 7, minute: 0), weekdays: [])

        XCTAssertEqual(schedule.oneTimeFireDate(afterArmingAt: armedAt, calendar: calendar), try Self.date(2026, 11, 18, 7, 0, calendar))
    }

    func testOneTimeFireDateRollsToNextDayWhenTimeHasPassed() throws {
        let calendar = Self.calendar("Asia/Almaty")
        let armedAt = try Self.date(2026, 11, 18, 7, 30, calendar)
        let schedule = AlarmSchedule(time: try AlarmTime(hour: 7, minute: 0), weekdays: [])

        XCTAssertEqual(schedule.oneTimeFireDate(afterArmingAt: armedAt, calendar: calendar), try Self.date(2026, 11, 19, 7, 0, calendar))
    }

    /// 02:30 doesn't exist on 2026-03-08 in New York (clocks jump 02:00 → 03:00).
    /// The fire date must still resolve rather than become nil.
    func testOneTimeFireDateForTimeSkippedBySpringForward() throws {
        let calendar = Self.calendar("America/New_York")
        let armedAt = try Self.date(2026, 3, 8, 0, 30, calendar)
        let schedule = AlarmSchedule(time: try AlarmTime(hour: 2, minute: 30), weekdays: [])

        let fireDate = try XCTUnwrap(schedule.oneTimeFireDate(afterArmingAt: armedAt, calendar: calendar))
        XCTAssertTrue(calendar.isDate(fireDate, inSameDayAs: armedAt))
        XCTAssertEqual(calendar.component(.hour, from: fireDate), 3)
    }

    /// Wall-clock semantics across fall back (2026-11-01 in New York): armed at
    /// 19:00 the evening before, a 07:00 alarm still fires at 07:00 local — 13
    /// absolute hours later because 01:00–02:00 happens twice.
    func testOneTimeFireDateAcrossFallBackKeepsWallClockTime() throws {
        let calendar = Self.calendar("America/New_York")
        let armedAt = try Self.date(2026, 10, 31, 19, 0, calendar)
        let schedule = AlarmSchedule(time: try AlarmTime(hour: 7, minute: 0), weekdays: [])

        let fireDate = try XCTUnwrap(schedule.oneTimeFireDate(afterArmingAt: armedAt, calendar: calendar))
        XCTAssertEqual(calendar.component(.hour, from: fireDate), 7)
        XCTAssertEqual(fireDate.timeIntervalSince(armedAt), 13 * 3600)
    }

    /// Relative schedules are expressed in local wall-clock time, so the same
    /// AlarmKit schedule is produced regardless of the device time zone.
    func testSystemScheduleIsIndependentOfTimeZone() throws {
        let schedule = AlarmSchedule(time: try AlarmTime(hour: 6, minute: 0), weekdays: .weekdays)
        let first = AlarmKitService.alarmKitSchedule(from: schedule)

        let tokyo = Self.calendar("Asia/Tokyo")
        let losAngeles = Self.calendar("America/Los_Angeles")
        let instant = try Self.date(2026, 6, 1, 6, 0, tokyo)
        XCTAssertNotEqual(tokyo.component(.hour, from: instant), losAngeles.component(.hour, from: instant))

        XCTAssertEqual(AlarmKitService.alarmKitSchedule(from: schedule), first)
    }

    // MARK: - Helpers

    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }
}
