//
//  AlarmKitService.swift
//  PushUpGame
//

import AlarmKit
import Foundation
// Needed only for `Color`: AlarmKit's `AlarmAttributes` requires a tint color.
import SwiftUI

/// AlarmKit-backed implementation of `AlarmSystemService`.
///
/// Alert-only: no countdown, snooze, or Live Activity presentation, so no
/// widget extension is required (AlarmKit only expects one for countdowns).
@MainActor
final class AlarmKitService: AlarmSystemService {
    private let manager: AlarmManager

    init(manager: AlarmManager = .shared) {
        self.manager = manager
    }

    var authorization: AlarmAuthorization {
        Self.authorization(from: manager.authorizationState)
    }

    func requestAuthorization() async throws(AlarmSchedulingError) -> AlarmAuthorization {
        do {
            return Self.authorization(from: try await manager.requestAuthorization())
        } catch {
            throw .authorizationRequestFailed(error.localizedDescription)
        }
    }

    func scheduledAlarms() throws(AlarmSchedulingError) -> [SystemAlarm] {
        do {
            return try manager.alarms.map(Self.systemAlarm(from:))
        } catch {
            throw .systemFailure(error.localizedDescription)
        }
    }

    func schedule(id: UUID, schedule: AlarmSchedule, title: String) async throws(AlarmSchedulingError) -> SystemAlarm {
        // Whether AlarmKit replaces an existing alarm with the same ID is
        // undocumented, so remove it explicitly to guarantee no duplicates.
        try cancel(id: id)

        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title))
        )
        let attributes = AlarmAttributes<PushUpAlarmMetadata>(
            presentation: presentation,
            metadata: PushUpAlarmMetadata(),
            tintColor: .accentColor
        )
        let configuration = AlarmManager.AlarmConfiguration<PushUpAlarmMetadata>.alarm(
            schedule: Self.alarmKitSchedule(from: schedule),
            attributes: attributes
        )

        do {
            let alarm = try await manager.schedule(id: id, configuration: configuration)
            return Self.systemAlarm(from: alarm)
        } catch AlarmManager.AlarmError.maximumLimitReached {
            throw .maximumLimitReached
        } catch {
            throw .systemFailure(error.localizedDescription)
        }
    }

    func cancel(id: UUID) throws(AlarmSchedulingError) {
        do {
            try manager.cancel(id: id)
        } catch {
            // Cancelling an unknown ID throws; treat "already gone" as success
            // so cancel is idempotent. Re-throw only if it's still scheduled.
            let stillScheduled = (try? manager.alarms.contains { $0.id == id }) ?? true
            if stillScheduled {
                throw .systemFailure(error.localizedDescription)
            }
        }
    }

    func alarmUpdates() -> AsyncStream<[SystemAlarm]> {
        let updates = manager.alarmUpdates
        return AsyncStream { continuation in
            let task = Task {
                for await alarms in updates {
                    continuation.yield(alarms.map(Self.systemAlarm(from:)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func authorizationUpdates() -> AsyncStream<AlarmAuthorization> {
        let updates = manager.authorizationUpdates
        return AsyncStream { continuation in
            let task = Task {
                for await state in updates {
                    continuation.yield(Self.authorization(from: state))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Mapping (internal for tests)

    /// Relative schedules follow the device's current time zone, so 07:00
    /// stays 07:00 local time across travel and DST changes.
    nonisolated static func alarmKitSchedule(from schedule: AlarmSchedule) -> Alarm.Schedule {
        let time = Alarm.Schedule.Relative.Time(hour: schedule.time.hour, minute: schedule.time.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence =
            schedule.isOneTime ? .never : .weekly(schedule.localeWeekdays)
        return .relative(Alarm.Schedule.Relative(time: time, repeats: recurrence))
    }

    /// `nil` for schedules this app never creates (fixed dates, timers), which
    /// the sync planner then treats as a mismatch to be replaced.
    nonisolated static func appSchedule(from schedule: Alarm.Schedule?) -> AlarmSchedule? {
        guard case .relative(let relative) = schedule,
              let time = try? AlarmTime(hour: relative.time.hour, minute: relative.time.minute) else {
            return nil
        }
        switch relative.repeats {
        case .never:
            return AlarmSchedule(time: time, weekdays: [])
        case .weekly(let weekdays):
            return AlarmSchedule(time: time, localeWeekdays: weekdays)
        @unknown default:
            return nil
        }
    }

    nonisolated static func authorization(from state: AlarmManager.AuthorizationState) -> AlarmAuthorization {
        switch state {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .denied
        }
    }

    nonisolated private static func systemAlarm(from alarm: Alarm) -> SystemAlarm {
        SystemAlarm(
            id: alarm.id,
            schedule: appSchedule(from: alarm.schedule),
            isAlerting: alarm.state == .alerting
        )
    }
}

/// Required by AlarmKit's generic API. Empty for now; the push-up challenge
/// PR can carry the target here.
nonisolated struct PushUpAlarmMetadata: AlarmMetadata {}
