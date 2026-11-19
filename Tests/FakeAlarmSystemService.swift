//
//  FakeAlarmSystemService.swift
//  PushUpGameTests
//

import Foundation

@testable import PushUpGame

/// In-memory stand-in for the system alarm scheduler. Can hold schedule and
/// authorization calls open to reproduce in-flight races deterministically.
@MainActor
final class FakeAlarmSystemService: AlarmSystemService {
    struct ScheduleCall: Equatable {
        let id: UUID
        let schedule: AlarmSchedule
        let title: String
    }

    var authorization: AlarmAuthorization = .authorized
    var requestResult: AlarmAuthorization = .authorized
    var requestError: AlarmSchedulingError?
    var scheduleError: AlarmSchedulingError?
    var cancelError: AlarmSchedulingError?
    var listError: AlarmSchedulingError?
    var alarms: [UUID: SystemAlarm] = [:]

    private(set) var requestCallCount = 0
    private(set) var scheduleCalls: [ScheduleCall] = []
    private(set) var cancelCalls: [UUID] = []

    var holdSchedules = false
    var holdAuthorizationRequest = false
    private var pendingSchedules: [CheckedContinuation<Void, Never>] = []
    private var pendingAuthorization: CheckedContinuation<Void, Never>?
    var pendingScheduleCount: Int { pendingSchedules.count }

    private var alarmContinuations: [AsyncStream<[SystemAlarm]>.Continuation] = []
    private var authorizationContinuations: [AsyncStream<AlarmAuthorization>.Continuation] = []

    func requestAuthorization() async throws(AlarmSchedulingError) -> AlarmAuthorization {
        requestCallCount += 1
        if holdAuthorizationRequest {
            await withCheckedContinuation { pendingAuthorization = $0 }
        }
        if let requestError { throw requestError }
        authorization = requestResult
        return requestResult
    }

    func scheduledAlarms() throws(AlarmSchedulingError) -> [SystemAlarm] {
        if let listError { throw listError }
        return Array(alarms.values)
    }

    func schedule(id: UUID, schedule: AlarmSchedule, title: String) async throws(AlarmSchedulingError) -> SystemAlarm {
        scheduleCalls.append(ScheduleCall(id: id, schedule: schedule, title: title))
        if holdSchedules {
            await withCheckedContinuation { pendingSchedules.append($0) }
        }
        if let scheduleError { throw scheduleError }
        // Replace semantics, like the real adapter (cancel-then-schedule).
        let alarm = SystemAlarm(id: id, schedule: schedule, isAlerting: false)
        alarms[id] = alarm
        return alarm
    }

    func cancel(id: UUID) throws(AlarmSchedulingError) {
        cancelCalls.append(id)
        if let cancelError { throw cancelError }
        alarms[id] = nil
    }

    func alarmUpdates() -> AsyncStream<[SystemAlarm]> {
        AsyncStream { alarmContinuations.append($0) }
    }

    func authorizationUpdates() -> AsyncStream<AlarmAuthorization> {
        AsyncStream { authorizationContinuations.append($0) }
    }

    // MARK: - Test controls

    func emitAlarms() {
        let snapshot = Array(alarms.values)
        alarmContinuations.forEach { $0.yield(snapshot) }
    }

    func emitAuthorization(_ state: AlarmAuthorization) {
        authorizationContinuations.forEach { $0.yield(state) }
    }

    func releasePendingSchedules() {
        let pending = pendingSchedules
        pendingSchedules.removeAll()
        pending.forEach { $0.resume() }
    }

    func releaseAuthorizationRequest() {
        pendingAuthorization?.resume()
        pendingAuthorization = nil
    }

    func resetCallLog() {
        scheduleCalls.removeAll()
        cancelCalls.removeAll()
        requestCallCount = 0
    }
}
