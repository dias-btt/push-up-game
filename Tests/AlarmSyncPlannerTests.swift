//
//  AlarmSyncPlannerTests.swift
//  PushUpGameTests
//

import XCTest

@testable import PushUpGame

final class AlarmSyncPlannerTests: XCTestCase {
    private let id = UUID()
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Almaty") ?? .gmt
        return calendar
    }

    // MARK: - Actions

    func testDeletedRecordWithSystemAlarmIsCancelled() {
        XCTAssertEqual(action(desired: nil, system: system(schedule: oneTime7am)), .cancel)
    }

    func testDeletedRecordWithoutSystemAlarmDoesNothing() {
        XCTAssertEqual(action(desired: nil, system: nil), .none)
    }

    func testDisabledAlarmIsCancelled() {
        XCTAssertEqual(action(desired: desired(enabled: false), system: system(schedule: oneTime7am)), .cancel)
        XCTAssertEqual(action(desired: desired(enabled: false), system: nil), .none)
    }

    func testEnabledUnscheduledAlarmIsScheduled() {
        XCTAssertEqual(action(desired: desired(), system: nil), .schedule(oneTime7am))
    }

    func testConfirmedMatchingAlarmIsLeftAlone() {
        let desired = desired(confirmedAt: date(hour: 6))
        XCTAssertEqual(action(desired: desired, system: system(schedule: oneTime7am)), .none)
    }

    func testUnconfirmedConfigurationIsRescheduledEvenIfTimeMatches() {
        // e.g. only the label changed, which the system schedule doesn't expose.
        XCTAssertEqual(action(desired: desired(), system: system(schedule: oneTime7am)), .schedule(oneTime7am))
    }

    func testChangedScheduleIsRescheduled() throws {
        let newSchedule = AlarmSchedule(time: try AlarmTime(hour: 8, minute: 0), weekdays: .weekdays)
        let desired = desired(schedule: newSchedule, confirmedAt: date(hour: 6))
        XCTAssertEqual(action(desired: desired, system: system(schedule: oneTime7am)), .schedule(newSchedule))
    }

    func testUnrecognisedSystemScheduleIsReplaced() {
        let desired = desired(confirmedAt: date(hour: 6))
        XCTAssertEqual(action(desired: desired, system: system(schedule: nil)), .schedule(oneTime7am))
    }

    func testRingingAlarmIsNotInterruptedForLabelOnlyChange() {
        XCTAssertEqual(action(desired: desired(), system: system(schedule: oneTime7am, alerting: true)), .none)
    }

    func testOneTimeAlarmMissingAfterFireTimeIsExpired() {
        let desired = desired(confirmedAt: date(hour: 6))
        XCTAssertEqual(action(desired: desired, system: nil, now: date(hour: 7, minute: 1)), .expire)
    }

    func testOneTimeAlarmMissingBeforeFireTimeIsRescheduled() {
        let desired = desired(confirmedAt: date(hour: 6))
        XCTAssertEqual(action(desired: desired, system: nil, now: date(hour: 6, minute: 30)), .schedule(oneTime7am))
    }

    func testRecurringAlarmMissingIsRescheduledNotExpired() throws {
        let recurring = AlarmSchedule(time: try AlarmTime(hour: 7, minute: 0), weekdays: .everyDay)
        let desired = desired(schedule: recurring, confirmedAt: date(hour: 6))
        XCTAssertEqual(action(desired: desired, system: nil, now: date(hour: 9)), .schedule(recurring))
    }

    func testUnconfirmedOneTimeAlarmIsNeverTreatedAsExpired() {
        // Saved locally, but the app died before the system accepted it.
        XCTAssertEqual(action(desired: desired(), system: nil, now: date(hour: 9)), .schedule(oneTime7am))
    }

    // MARK: - Presentation upgrade (alarms scheduled before "Start Push-Ups")

    func testAlarmConfirmedWithoutPresentationVersionIsRescheduled() {
        let legacy = desired(confirmedAt: date(hour: 6), presentationVersion: nil)
        XCTAssertEqual(action(desired: legacy, system: system(schedule: oneTime7am)), .schedule(oneTime7am))
    }

    func testRecurringAlarmWithOutdatedPresentationIsRescheduled() throws {
        let recurring = AlarmSchedule(time: try AlarmTime(hour: 7, minute: 0), weekdays: .everyDay)
        let legacy = desired(schedule: recurring, confirmedAt: date(hour: 6), presentationVersion: 0)
        XCTAssertEqual(
            action(desired: legacy, system: system(schedule: recurring), now: date(hour: 9)),
            .schedule(recurring)
        )
    }

    func testAlarmWithCurrentPresentationIsNotRescheduledAgain() {
        // After the upgrade the confirmation carries the current version: no loop.
        let upgraded = desired(confirmedAt: date(hour: 6))
        XCTAssertEqual(action(desired: upgraded, system: system(schedule: oneTime7am)), .none)
    }

    func testRingingAlarmWithOutdatedPresentationIsNotInterrupted() {
        let legacy = desired(confirmedAt: date(hour: 6), presentationVersion: nil)
        XCTAssertEqual(action(desired: legacy, system: system(schedule: oneTime7am, alerting: true)), .none)
    }

    func testOutdatedOneTimeAlarmPastFireTimeIsNotRearmed() {
        // Still listed just after 07:00 but not yet removed by the system:
        // replacing it would schedule it for tomorrow.
        let legacy = desired(confirmedAt: date(hour: 6), presentationVersion: nil)
        XCTAssertEqual(
            action(desired: legacy, system: system(schedule: oneTime7am), now: date(hour: 7, minute: 1)),
            .none
        )
    }

    func testOutdatedOneTimeAlarmMissingAfterFireTimeStillExpires() {
        let legacy = desired(confirmedAt: date(hour: 6), presentationVersion: nil)
        XCTAssertEqual(action(desired: legacy, system: nil, now: date(hour: 7, minute: 1)), .expire)
    }

    func testDisabledAlarmWithOutdatedPresentationIsStillCancelled() {
        let legacy = desired(enabled: false, confirmedAt: date(hour: 6), presentationVersion: nil)
        XCTAssertEqual(action(desired: legacy, system: system(schedule: oneTime7am)), .cancel)
    }

    func testOutdatedPresentationStillReportsScheduled() {
        // It will ring; only the extra button is missing until the upgrade.
        let legacy = desired(confirmedAt: date(hour: 6), presentationVersion: nil)
        XCTAssertEqual(status(legacy, system(schedule: oneTime7am)), .scheduled)
    }

    // MARK: - Status

    func testStatusPriorities() {
        let enabled = desired()
        let matching = system(schedule: oneTime7am)

        XCTAssertEqual(status(desired(enabled: false), matching), .off)
        XCTAssertEqual(status(enabled, matching, isUpdating: true), .updating)
        XCTAssertEqual(status(enabled, matching, authorization: .denied), .permissionRequired)
        XCTAssertEqual(status(enabled, nil, authorization: .notDetermined), .permissionRequired)
        XCTAssertEqual(status(enabled, matching), .scheduled)
        XCTAssertEqual(status(enabled, nil, error: .maximumLimitReached), .failed(.maximumLimitReached))
        XCTAssertEqual(status(enabled, nil), .notScheduled)
    }

    func testStatusIsNotScheduledWhenSystemScheduleDiffers() throws {
        let other = system(schedule: AlarmSchedule(time: try AlarmTime(hour: 9, minute: 0), weekdays: []))
        XCTAssertEqual(status(desired(), other), .notScheduled)
    }

    // MARK: - Helpers

    private var oneTime7am: AlarmSchedule {
        AlarmSchedule(time: AlarmTime(clampingHour: 7, minute: 0), weekdays: [])
    }

    private func desired(
        schedule: AlarmSchedule? = nil,
        enabled: Bool = true,
        confirmedAt: Date? = nil,
        presentationVersion: Int? = AlarmSyncPlanner.currentPresentationVersion
    ) -> DesiredAlarm {
        DesiredAlarm(
            id: id,
            title: "Alarm",
            schedule: schedule ?? oneTime7am,
            isEnabled: enabled,
            scheduleConfirmedAt: confirmedAt,
            confirmedPresentationVersion: confirmedAt == nil ? nil : presentationVersion
        )
    }

    private func system(schedule: AlarmSchedule?, alerting: Bool = false) -> SystemAlarm {
        SystemAlarm(id: id, schedule: schedule, isAlerting: alerting)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: hour, minute: minute)) ?? .distantPast
    }

    private func action(desired: DesiredAlarm?, system: SystemAlarm?, now: Date? = nil) -> AlarmSyncAction {
        AlarmSyncPlanner.action(desired: desired, system: system, now: now ?? date(hour: 6, minute: 30), calendar: calendar)
    }

    private func status(
        _ desired: DesiredAlarm,
        _ system: SystemAlarm?,
        authorization: AlarmAuthorization = .authorized,
        error: AlarmSchedulingError? = nil,
        isUpdating: Bool = false
    ) -> AlarmSchedulingStatus {
        AlarmSyncPlanner.status(
            desired: desired,
            system: system,
            authorization: authorization,
            lastError: error,
            isUpdating: isUpdating
        )
    }
}
