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
    /// The alert presentation version the system confirmed alongside
    /// `scheduleConfirmedAt`. `nil` for alarms confirmed before versioning
    /// existed (i.e. scheduled without the "Start Push-Ups" action).
    let confirmedPresentationVersion: Int?
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
/// - enabled, confirmed with an older alert presentation → reschedule once to
///   pick up the new presentation, unless it is ringing or is a one-time
///   alarm whose fire time has already passed (rescheduling would rearm it)
/// - enabled, missing from the system:
///   - one-time whose first fire date has passed → expire
///   - otherwise → schedule (repairs failed or interrupted scheduling)
nonisolated enum AlarmSyncPlanner {
    /// Version of the alert presentation `AlarmKitService` schedules.
    /// Bump whenever the alert's buttons or intents change so alarms
    /// scheduled by an older build are upgraded on the next reconciliation.
    /// 1: added the "Start Push-Ups" secondary action.
    static let currentPresentationVersion = 1

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
            let scheduleMatches = system.schedule == desired.schedule
            // Never interrupt a ringing alarm just to refresh its label or
            // presentation: the user may be tapping one of its buttons.
            if system.isAlerting && scheduleMatches {
                return .none
            }
            guard desired.scheduleConfirmedAt != nil, scheduleMatches else {
                return .schedule(desired.schedule)
            }
            if desired.confirmedPresentationVersion == currentPresentationVersion {
                return .none
            }
            // Outdated presentation. A one-time alarm still listed after its
            // fire time is about to be removed by the system; replacing it now
            // would schedule it for tomorrow instead of letting it expire.
            if hasOneTimeFireTimePassed(desired, now: now, calendar: calendar) {
                return .none
            }
            return .schedule(desired.schedule)
        }

        if hasOneTimeFireTimePassed(desired, now: now, calendar: calendar) {
            return .expire
        }
        return .schedule(desired.schedule)
    }

    private static func hasOneTimeFireTimePassed(_ desired: DesiredAlarm, now: Date, calendar: Calendar) -> Bool {
        guard desired.schedule.isOneTime,
              let confirmedAt = desired.scheduleConfirmedAt,
              let fireDate = desired.schedule.oneTimeFireDate(afterArmingAt: confirmedAt, calendar: calendar) else {
            return false
        }
        return fireDate <= now
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
