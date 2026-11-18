//
//  AlarmScheduleCoordinatorTests.swift
//  PushUpGameTests
//

import SwiftData
import XCTest

@testable import PushUpGame

/// End-to-end sync behaviour against a fake system scheduler and an isolated
/// in-memory store. No real AlarmKit alarms are created.
@MainActor
final class AlarmScheduleCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var service: FakeAlarmSystemService!
    private var coordinator: AlarmScheduleCoordinator!
    private var currentDate = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Almaty") ?? .gmt
        return calendar
    }()

    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try AppDependencies.makeModelContainer(inMemory: true)
        service = FakeAlarmSystemService()
        coordinator = makeCoordinator()
    }

    override func tearDown() async throws {
        coordinator?.stopObserving()
        coordinator = nil
        service = nil
        container = nil
    }

    // MARK: - Scheduling

    func testSchedulingAnEnabledAlarm() async throws {
        let record = try insert(AlarmConfiguration(title: "Gym", repeatDays: .weekdays))

        await coordinator.sync(record.id)

        XCTAssertEqual(service.scheduleCalls.map(\.id), [record.id])
        XCTAssertEqual(service.scheduleCalls.first?.schedule, AlarmSchedule(time: .wakeUpDefault, weekdays: .weekdays))
        XCTAssertEqual(service.scheduleCalls.first?.title, "Gym")
        XCTAssertEqual(coordinator.status(for: record), .scheduled)
        XCTAssertEqual(record.scheduleConfirmedAt, currentDate)
    }

    func testOneTimeAlarmIsScheduledWithoutWeekdays() async throws {
        let record = try insert(AlarmConfiguration())

        await coordinator.sync(record.id)

        XCTAssertEqual(service.scheduleCalls.first?.schedule.isOneTime, true)
    }

    func testRepeatedSyncOfSameConfigurationDoesNotReschedule() async throws {
        let record = try insert(AlarmConfiguration())

        await coordinator.sync(record.id)
        await coordinator.sync(record.id)
        await coordinator.reconcileAll()

        XCTAssertEqual(service.scheduleCalls.count, 1)
        XCTAssertEqual(service.alarms.count, 1)
    }

    func testSchedulingFailureIsVisibleAndRetryRecovers() async throws {
        let record = try insert(AlarmConfiguration())
        service.scheduleError = .systemFailure("boom")

        await coordinator.sync(record.id)

        XCTAssertEqual(coordinator.status(for: record), .failed(.systemFailure("boom")))
        XCTAssertNil(record.scheduleConfirmedAt)
        XCTAssertTrue(record.isEnabled, "the user's intent is kept so it can be retried")

        service.scheduleError = nil
        await coordinator.sync(record.id)

        XCTAssertEqual(coordinator.status(for: record), .scheduled)
    }

    func testMaximumLimitIsReportedAsNonRetryable() async throws {
        let record = try insert(AlarmConfiguration())
        service.scheduleError = .maximumLimitReached

        await coordinator.sync(record.id)

        guard case .failed(let error) = coordinator.status(for: record) else {
            return XCTFail("expected failure status")
        }
        XCTAssertFalse(error.isRetryable)
    }

    // MARK: - Authorization

    func testDeniedAuthorizationNeverSchedules() async throws {
        service.authorization = .denied
        coordinator = makeCoordinator()
        let record = try insert(AlarmConfiguration())

        await coordinator.sync(record.id)

        XCTAssertTrue(service.scheduleCalls.isEmpty)
        XCTAssertEqual(service.requestCallCount, 0, "the system won't re-prompt once denied")
        XCTAssertEqual(coordinator.status(for: record), .permissionRequired)
    }

    func testFirstUserActionPromptsAndSchedulesWhenGranted() async throws {
        service.authorization = .notDetermined
        service.requestResult = .authorized
        coordinator = makeCoordinator()
        let record = try insert(AlarmConfiguration())

        await coordinator.sync(record.id)

        XCTAssertEqual(service.requestCallCount, 1)
        XCTAssertEqual(coordinator.status(for: record), .scheduled)
    }

    func testPromptDeclinedLeavesAlarmUnscheduled() async throws {
        service.authorization = .notDetermined
        service.requestResult = .denied
        coordinator = makeCoordinator()
        let record = try insert(AlarmConfiguration())

        await coordinator.sync(record.id)

        XCTAssertTrue(service.scheduleCalls.isEmpty)
        XCTAssertEqual(coordinator.status(for: record), .permissionRequired)
    }

    func testAuthorizationRequestErrorIsSurfaced() async throws {
        service.authorization = .notDetermined
        service.requestError = .authorizationRequestFailed("nope")
        coordinator = makeCoordinator()
        let record = try insert(AlarmConfiguration())

        await coordinator.sync(record.id)

        XCTAssertTrue(service.scheduleCalls.isEmpty)
        XCTAssertEqual(coordinator.lastErrors[record.id], .authorizationRequestFailed("nope"))
    }

    func testBackgroundReconciliationNeverPrompts() async throws {
        service.authorization = .notDetermined
        coordinator = makeCoordinator()
        _ = try insert(AlarmConfiguration())

        await coordinator.reconcileAll()

        XCTAssertEqual(service.requestCallCount, 0)
        XCTAssertTrue(service.scheduleCalls.isEmpty)
    }

    func testGrantingPermissionInSettingsSchedulesPendingAlarms() async throws {
        service.authorization = .denied
        coordinator = makeCoordinator()
        let record = try insert(AlarmConfiguration())
        await coordinator.sync(record.id)
        XCTAssertEqual(coordinator.status(for: record), .permissionRequired)

        // Returning from Settings: the foreground pass re-reads authorization.
        service.authorization = .authorized
        await coordinator.reconcileAll()

        XCTAssertEqual(coordinator.status(for: record), .scheduled)
    }

    func testRevokingPermissionStopsClaimingScheduled() async throws {
        let record = try insert(AlarmConfiguration())
        await coordinator.sync(record.id)
        XCTAssertEqual(coordinator.status(for: record), .scheduled)

        service.authorization = .denied
        await coordinator.reconcileAll()

        XCTAssertEqual(coordinator.status(for: record), .permissionRequired)
    }

    func testAuthorizationUpdateTriggersReconciliation() async throws {
        service.authorization = .denied
        coordinator = makeCoordinator()
        let record = try insert(AlarmConfiguration())
        coordinator.startObserving()

        service.authorization = .authorized
        service.emitAuthorization(.authorized)
        try await waitUntil { self.service.scheduleCalls.count == 1 }

        XCTAssertEqual(coordinator.status(for: record), .scheduled)
    }

    // MARK: - Enable / disable / edit / delete

    func testDisableCancelsAndReEnableReschedules() async throws {
        let record = try insert(AlarmConfiguration())
        await coordinator.sync(record.id)

        record.setEnabled(false)
        try context.save()
        await coordinator.sync(record.id)

        XCTAssertEqual(service.cancelCalls, [record.id])
        XCTAssertTrue(service.alarms.isEmpty)
        XCTAssertEqual(coordinator.status(for: record), .off)

        record.setEnabled(true)
        try context.save()
        await coordinator.sync(record.id)

        XCTAssertEqual(service.scheduleCalls.count, 2)
        XCTAssertEqual(coordinator.status(for: record), .scheduled)
    }

    func testEditingReschedulesUnderTheSameID() async throws {
        let record = try insert(AlarmConfiguration())
        await coordinator.sync(record.id)

        var edited = record.configuration
        edited.time = try AlarmTime(hour: 9, minute: 45)
        edited.repeatDays = .weekends
        try record.update(with: edited)
        try context.save()
        await coordinator.sync(record.id)

        XCTAssertEqual(service.scheduleCalls.map(\.id), [record.id, record.id])
        XCTAssertEqual(service.alarms.count, 1, "rescheduling replaces, never duplicates")
        XCTAssertEqual(service.alarms[record.id]?.schedule, AlarmSchedule(time: try AlarmTime(hour: 9, minute: 45), weekdays: .weekends))
    }

    func testLabelOnlyEditStillReschedules() async throws {
        let record = try insert(AlarmConfiguration(title: "Old"))
        await coordinator.sync(record.id)

        var edited = record.configuration
        edited.title = "New"
        try record.update(with: edited)
        try context.save()
        await coordinator.sync(record.id)

        XCTAssertEqual(service.scheduleCalls.last?.title, "New")
    }

    func testSavingUnchangedConfigurationDoesNotReschedule() async throws {
        let record = try insert(AlarmConfiguration())
        await coordinator.sync(record.id)

        try record.update(with: record.configuration)
        try context.save()
        await coordinator.sync(record.id)

        XCTAssertEqual(service.scheduleCalls.count, 1)
    }

    func testDeletingCancelsSystemAlarm() async throws {
        let record = try insert(AlarmConfiguration())
        let id = record.id
        await coordinator.sync(id)

        context.delete(record)
        try context.save()
        await coordinator.sync(id)

        XCTAssertEqual(service.cancelCalls, [id])
        XCTAssertTrue(service.alarms.isEmpty)
    }

    func testFailedCancelIsRetriedOnNextReconciliation() async throws {
        let record = try insert(AlarmConfiguration())
        let id = record.id
        await coordinator.sync(id)

        service.cancelError = .systemFailure("busy")
        context.delete(record)
        try context.save()
        await coordinator.sync(id)
        XCTAssertNotNil(service.alarms[id], "orphan left behind by the failed cancel")

        service.cancelError = nil
        await coordinator.reconcileAll()

        XCTAssertTrue(service.alarms.isEmpty)
    }

    // MARK: - Duplicate / concurrent operations

    func testRapidSyncsAreCoalescedAndConvergeOnLatestState() async throws {
        let record = try insert(AlarmConfiguration())
        service.holdSchedules = true

        let first = Task { await coordinator.sync(record.id) }
        try await waitUntil { self.service.pendingScheduleCount == 1 }
        XCTAssertTrue(coordinator.isUpdating(record.id))
        XCTAssertEqual(coordinator.status(for: record), .updating)

        // User toggles off, on, off while the first schedule is in flight.
        for enabled in [false, true, false] {
            record.setEnabled(enabled)
            try context.save()
            await coordinator.sync(record.id)
        }
        XCTAssertEqual(service.scheduleCalls.count, 1, "no overlapping system calls")

        service.holdSchedules = false
        service.releasePendingSchedules()
        await first.value

        XCTAssertTrue(service.alarms.isEmpty, "final state is disabled")
        XCTAssertFalse(coordinator.isUpdating(record.id))
        XCTAssertEqual(coordinator.status(for: record), .off)
        XCTAssertNil(record.scheduleConfirmedAt, "a confirmation must not apply to a stale configuration")
    }

    func testConcurrentFirstSchedulesShareOnePermissionPrompt() async throws {
        service.authorization = .notDetermined
        service.requestResult = .authorized
        service.holdAuthorizationRequest = true
        coordinator = makeCoordinator()
        let first = try insert(AlarmConfiguration(title: "A"))
        let second = try insert(AlarmConfiguration(title: "B"))

        let syncFirst = Task { await coordinator.sync(first.id) }
        let syncSecond = Task { await coordinator.sync(second.id) }
        try await waitUntil { self.service.requestCallCount == 1 }
        service.releaseAuthorizationRequest()
        await syncFirst.value
        await syncSecond.value

        XCTAssertEqual(service.requestCallCount, 1)
        XCTAssertEqual(Set(service.alarms.keys), [first.id, second.id])
    }

    // MARK: - Reconciliation after restart / system changes

    func testRelaunchRepairsAllInconsistencies() async throws {
        // State left by a previous run that was killed mid-way:
        let neverScheduled = try insert(AlarmConfiguration(title: "saved, never scheduled"))
        let disabledButScheduled = try insert(AlarmConfiguration(title: "disabled", isEnabled: false))
        let healthy = try insert(AlarmConfiguration(title: "healthy"))
        healthy.confirmSchedule(healthy.schedule, title: "healthy", at: currentDate)
        try context.save()

        let orphanID = UUID()
        service.alarms = [
            orphanID: SystemAlarm(id: orphanID, schedule: healthy.schedule, isAlerting: false),
            disabledButScheduled.id: SystemAlarm(id: disabledButScheduled.id, schedule: disabledButScheduled.schedule, isAlerting: false),
            healthy.id: SystemAlarm(id: healthy.id, schedule: healthy.schedule, isAlerting: false),
        ]

        // Fresh coordinator = app relaunch.
        coordinator = makeCoordinator()
        await coordinator.reconcileAll()

        XCTAssertEqual(Set(service.alarms.keys), [neverScheduled.id, healthy.id])
        XCTAssertEqual(Set(service.cancelCalls), [orphanID, disabledButScheduled.id])
        XCTAssertEqual(service.scheduleCalls.map(\.id), [neverScheduled.id], "healthy alarm untouched")

        // A second launch is a no-op: no duplicates, no churn.
        service.resetCallLog()
        coordinator = makeCoordinator()
        await coordinator.reconcileAll()
        XCTAssertTrue(service.scheduleCalls.isEmpty)
        XCTAssertTrue(service.cancelCalls.isEmpty)
    }

    func testExpiredOneTimeAlarmIsTurnedOffInsteadOfRearmed() async throws {
        let sevenAM = try AlarmTime(hour: 7, minute: 0)
        currentDate = try date(hour: 6)
        let record = try insert(AlarmConfiguration(time: sevenAM))
        await coordinator.sync(record.id)

        // It rang at 07:00, was stopped, and the system removed it while the app was closed.
        service.alarms = [:]
        currentDate = try date(hour: 8)
        coordinator = makeCoordinator()
        await coordinator.reconcileAll()

        XCTAssertFalse(record.isEnabled)
        XCTAssertEqual(coordinator.status(for: record), .off)
        XCTAssertEqual(service.scheduleCalls.count, 1, "not re-armed for tomorrow")
    }

    func testAlarmRemovedFromSystemWhileRunningIsReconciled() async throws {
        let recurring = try insert(AlarmConfiguration(repeatDays: .everyDay))
        await coordinator.sync(recurring.id)
        coordinator.startObserving()

        // Something outside the app removed it; the update stream reports it.
        service.alarms = [:]
        service.emitAlarms()
        try await waitUntil { self.service.scheduleCalls.count == 2 }

        XCTAssertEqual(coordinator.status(for: recurring), .scheduled)
    }

    func testSystemListFailureIsReported() async throws {
        let record = try insert(AlarmConfiguration())
        service.listError = .systemFailure("unavailable")

        await coordinator.sync(record.id)

        XCTAssertTrue(service.scheduleCalls.isEmpty)
        XCTAssertEqual(coordinator.status(for: record), .failed(.systemFailure("unavailable")))
    }

    // MARK: - Helpers

    private func makeCoordinator() -> AlarmScheduleCoordinator {
        AlarmScheduleCoordinator(
            service: service,
            modelContext: context,
            now: { [unowned self] in self.currentDate },
            calendar: { [unowned self] in self.calendar }
        )
    }

    @discardableResult
    private func insert(_ configuration: AlarmConfiguration) throws -> AlarmRecord {
        let record = try AlarmRecord(configuration: configuration)
        context.insert(record)
        try context.save()
        return record
    }

    private func date(hour: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: hour)))
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("condition not met within \(timeout)s")
                throw CancellationError()
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}
