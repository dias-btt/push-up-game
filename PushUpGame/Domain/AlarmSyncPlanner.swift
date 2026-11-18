//
//  AlarmSyncPlanner.swift
//  PushUpGame
//

import Foundation

/// The user's desired state for one alarm, as stored locally.
nonisolated struct DesiredAlarm: Equatable, Sendable {
    let id: UUID
    let title: String
    let schedule: AlarmSchedule
    let isEnabled: Bool
    /// When the system last confirmed scheduling *this exact* configuration.
    /// `nil` means the current configuration has never been confirmed.
    let scheduleConfirmedAt: Date?
}

/// One alarm as the system currently holds it.
nonisolated struct SystemAlarm: Equatable, Sendable {
    let id: UUID
    /// `nil` when the system schedule isn't a relative schedule we created.
    let schedule: AlarmSchedule?
    let isAlerting: Bool
}

nonisolated enum AlarmSyncAction: Equatable, Sendable {
    case none
    /// Cancel any existing system alarm with this ID, then schedule the desired one.
    case schedule(AlarmSchedule)
    case cancel
    /// A one-time alarm already rang: turn it off locally, like the Clock app.
    case expire
}

/// Pure reconciliation rules between desired (local) and actual (system) state.
///
/// Every sync — after a user edit, at launch, on foreground, and on each
/// system alarm update — runs the same rules, so any partial failure or
/// interrupted operation converges on the next pass:
/// - local record deleted, system alarm left behind → cancel (orphan)
/// - disabled locally, still scheduled → cancel
/// - enabled, scheduled with the confirmed configuration → nothing (idempotent)
/// - enabled, configuration changed since last confirmation → reschedule
/// - enabled, missing from the system:
///   - one-time whose first fire date has passed → expire
///   - otherwise → schedule (repairs failed or interrupted scheduling)
nonisolated enum AlarmSyncPlanner {
    static func action(
        desired: DesiredAlarm?,
        system: SystemAlarm?,
        now: Date,
        calendar: Calendar
    ) -> AlarmSyncAction {
        guard let desired, desired.isEnabled else {
            return system == nil ? .none : .cancel
        }

        if let system {
            let isConfirmed = desired.scheduleConfirmedAt != nil && system.schedule == desired.schedule
            // Never interrupt a ringing alarm just to refresh its label.
            if isConfirmed || (system.isAlerting && system.schedule == desired.schedule) {
                return .none
            }
            return .schedule(desired.schedule)
        }

        if desired.schedule.isOneTime,
           let confirmedAt = desired.scheduleConfirmedAt,
           let fireDate = desired.schedule.oneTimeFireDate(afterArmingAt: confirmedAt, calendar: calendar),
           fireDate <= now {
            return .expire
        }
        return .schedule(desired.schedule)
    }

    static func status(
        desired: DesiredAlarm,
        system: SystemAlarm?,
        authorization: AlarmAuthorization,
        lastError: AlarmSchedulingError?,
        isUpdating: Bool
    ) -> AlarmSchedulingStatus {
        guard desired.isEnabled else { return .off }
        if isUpdating { return .updating }
        // Even if the system still lists the alarm, don't claim it will ring
        // once permission is gone.
        guard authorization == .authorized else { return .permissionRequired }
        if let system, system.schedule == desired.schedule {
            return .scheduled
        }
        if let lastError {
            return .failed(lastError)
        }
        return .notScheduled
    }
}
