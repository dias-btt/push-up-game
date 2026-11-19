//
//  AlarmSchedulingStatus.swift
//  PushUpGame
//

import Foundation

/// What the *system* will do with an alarm, kept separate from what the user
/// configured. Always derived (see `AlarmSyncPlanner.status`) from the live
/// system alarm list and authorization — never persisted — so the UI can't
/// claim an alarm is scheduled when the system disagrees.
nonisolated enum AlarmSchedulingStatus: Equatable, Sendable {
    /// The user turned the alarm off.
    case off
    /// A schedule/cancel operation for this alarm is in flight.
    case updating
    /// Enabled, but the app is not (or not yet) allowed to schedule alarms.
    case permissionRequired
    /// The system holds an alarm with this ID and the expected schedule.
    case scheduled
    /// The last attempt failed; the alarm will not ring until it succeeds.
    case failed(AlarmSchedulingError)
    /// Enabled, but no matching system alarm exists (e.g. awaiting reconciliation).
    case notScheduled
}
