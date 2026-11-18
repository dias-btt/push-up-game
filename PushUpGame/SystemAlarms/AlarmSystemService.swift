//
//  AlarmSystemService.swift
//  PushUpGame
//

import Foundation

/// The system alarm scheduler, expressed in domain types so the sync logic
/// can be tested with a fake. The only production implementation is
/// `AlarmKitService`.
///
/// Main-actor isolated because its sole client (`AlarmScheduleCoordinator`)
/// is, and the underlying system manager is a shared, non-Sendable object.
@MainActor
protocol AlarmSystemService: AnyObject {
    var authorization: AlarmAuthorization { get }

    /// Shows the system permission prompt when undetermined.
    func requestAuthorization() async throws(AlarmSchedulingError) -> AlarmAuthorization

    /// Current system alarms owned by this app.
    func scheduledAlarms() throws(AlarmSchedulingError) -> [SystemAlarm]

    /// Schedules an alert-only alarm under `id`, replacing any existing alarm
    /// with that ID so repeated calls never create duplicates.
    func schedule(id: UUID, schedule: AlarmSchedule, title: String) async throws(AlarmSchedulingError) -> SystemAlarm

    /// Cancels the alarm with `id`. Succeeds if no such alarm exists.
    func cancel(id: UUID) throws(AlarmSchedulingError)

    /// Emits the full alarm list whenever it changes, including changes made
    /// while the app wasn't running and alarms removed after they ring.
    func alarmUpdates() -> AsyncStream<[SystemAlarm]>

    /// Emits authorization changes, e.g. after the user returns from Settings.
    func authorizationUpdates() -> AsyncStream<AlarmAuthorization>
}
