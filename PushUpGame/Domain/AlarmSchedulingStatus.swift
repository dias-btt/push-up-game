//
//  AlarmSchedulingStatus.swift
//  PushUpGame
//

import Foundation

/// What the *system* will do with an alarm, kept separate from what the user
/// configured so that saving locally never implies the alarm will ring.
///
/// Deliberately not persisted: once system scheduling exists, the system is the
/// source of truth for what is scheduled, and a cached copy would drift (e.g.
/// after a reinstall or a permission change). This build has no scheduler, so an
/// enabled alarm always resolves to `.notScheduled`.
nonisolated enum AlarmSchedulingStatus: Equatable, Sendable {
    /// The user turned the alarm off.
    case off
    /// The alarm is enabled but no system alarm exists for it.
    case notScheduled

    init(isEnabled: Bool) {
        self = isEnabled ? .notScheduled : .off
    }
}
