//
//  AlarmScheduleCoordinator.swift
//  PushUpGame
//

import Foundation
import Observation
import SwiftData

/// Keeps system alarms consistent with the locally stored alarm records.
///
/// **Source of truth.** SwiftData holds what the user *wants*; the system
/// alarm list holds what is *actually* scheduled. The UI status is always
/// derived from the live system list (`systemAlarms`), never from a stored flag.
///
/// **Write order.** Callers persist the desired state first, then call
/// `sync(_:)`. If the system call then fails, the record keeps the user's
/// intent and the row shows "Scheduling failed" with Retry; the next
/// reconciliation (launch, foreground, any system update) retries it.
///
/// **Partial failures and recovery** (all repaired by `reconcileAll()`):
/// - Saved locally, scheduling failed or app killed before scheduling →
///   enabled + missing → scheduled on next pass.
/// - Scheduled, but saving the confirmation failed → next pass sees an
///   unconfirmed configuration and reschedules under the same ID (no duplicate).
/// - Deleted locally, cancel failed or app killed → system alarm with no record
///   → cancelled as an orphan.
/// - Disabled locally, cancel failed → cancelled on next pass.
/// - One-time alarm rang and was removed by the system → turned off locally.
/// - Alarm scheduled by an older build with an outdated alert presentation →
///   rescheduled once under the same ID; the new confirmation stops repeats.
///
/// **Concurrency.** Operations are serialized per alarm ID. A sync requested
/// while one is in flight is coalesced into a single follow-up pass that reads
/// the latest stored state, so rapid toggles converge on the final value
/// without interleaving cancel/schedule calls.
@MainActor
@Observable
final class AlarmScheduleCoordinator {
    private(set) var authorization: AlarmAuthorization
    private(set) var systemAlarms: [UUID: SystemAlarm] = [:]
    private(set) var lastErrors: [UUID: AlarmSchedulingError] = [:]
    private(set) var updatingIDs: Set<UUID> = []

    @ObservationIgnored private let service: AlarmSystemService
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private var pendingResyncIDs: Set<UUID> = []
    @ObservationIgnored private var authorizationRequest: Task<AlarmAuthorization, Never>?
    @ObservationIgnored private var lastAuthorizationRequestError: AlarmSchedulingError?
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []

    init(
        service: AlarmSystemService,
        modelContext: ModelContext,
        now: @escaping () -> Date = { .now },
        calendar: @escaping () -> Calendar = { .current }
    ) {
        self.service = service
        self.modelContext = modelContext
        self.now = now
        self.calendar = calendar
        self.authorization = service.authorization
    }

    // MARK: - Lifecycle

    /// Starts observing system alarm and authorization changes. Idempotent.
    func startObserving() {
        guard observationTasks.isEmpty else { return }

        let alarmUpdates = service.alarmUpdates()
        let authorizationUpdates = service.authorizationUpdates()

        observationTasks.append(Task { [weak self] in
            for await alarms in alarmUpdates {
                guard let self else { return }
                self.replaceSystemAlarms(alarms)
                await self.reconcileAll(refreshingSystemAlarms: false)
            }
        })
        observationTasks.append(Task { [weak self] in
            for await state in authorizationUpdates {
                guard let self else { return }
                let wasAuthorized = self.authorization == .authorized
                self.authorization = state
                if state == .authorized, !wasAuthorized {
                    await self.reconcileAll()
                }
            }
        })
    }

    func stopObserving() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
    }

    // MARK: - Status

    func status(for record: AlarmRecord) -> AlarmSchedulingStatus {
        AlarmSyncPlanner.status(
            desired: record.desiredState,
            system: systemAlarms[record.id],
            authorization: authorization,
            lastError: lastErrors[record.id],
            isUpdating: updatingIDs.contains(record.id)
        )
    }

    func isUpdating(_ id: UUID) -> Bool {
        updatingIDs.contains(id)
    }

    // MARK: - Sync

    /// Brings the system alarm for `id` in line with the stored record (or its
    /// absence). `userInitiated` allows showing the permission prompt; background
    /// reconciliation never prompts.
    func sync(_ id: UUID, userInitiated: Bool = true) async {
        if updatingIDs.contains(id) {
            pendingResyncIDs.insert(id)
            return
        }
        updatingIDs.insert(id)
        defer { updatingIDs.remove(id) }

        repeat {
            pendingResyncIDs.remove(id)
            await performSync(id, userInitiated: userInitiated)
        } while pendingResyncIDs.contains(id)
    }

    /// Reconciles every stored record and every system alarm (catching orphans).
    /// Runs at launch, on foreground, and on each system update.
    func reconcileAll(refreshingSystemAlarms: Bool = true) async {
        authorization = service.authorization
        if refreshingSystemAlarms {
            guard refreshSystemAlarms() else { return }
        }
        let recordIDs: [UUID]
        do {
            recordIDs = try modelContext.fetch(FetchDescriptor<AlarmRecord>()).map(\.id)
        } catch {
            // Without the local list we can't tell orphans from real alarms;
            // do nothing rather than cancel alarms the user still wants.
            return
        }
        let allIDs = Set(recordIDs).union(systemAlarms.keys)
        for id in allIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            await sync(id, userInitiated: false)
        }
    }

    /// Explicit permission request from the UI (e.g. an "Allow" button).
    func requestAuthorization() async {
        _ = await ensureAuthorized(prompt: true)
        await reconcileAll()
    }

    // MARK: - Private

    private func performSync(_ id: UUID, userInitiated: Bool) async {
        guard refreshSystemAlarms(recordingErrorFor: id) else { return }

        let record: AlarmRecord?
        do {
            record = try fetchRecord(id)
        } catch {
            lastErrors[id] = .persistenceFailed(error.localizedDescription)
            return
        }

        let action = AlarmSyncPlanner.action(
            desired: record?.desiredState,
            system: systemAlarms[id],
            now: now(),
            calendar: calendar()
        )

        switch action {
        case .none:
            lastErrors[id] = nil

        case .cancel:
            do {
                try service.cancel(id: id)
                systemAlarms[id] = nil
                lastErrors[id] = nil
            } catch {
                lastErrors[id] = AlarmSchedulingError(error)
            }

        case .expire:
            record?.markExpired()
            saveContext(recordingErrorFor: id)

        case .schedule(let schedule):
            guard let record else { return }
            let title = record.desiredState.title
            guard await ensureAuthorized(prompt: userInitiated) else {
                // Status shows "Permission required" from `authorization`;
                // a failed prompt is surfaced as an error instead.
                lastErrors[id] = lastAuthorizationRequestError
                return
            }
            do {
                let scheduled = try await service.schedule(id: id, schedule: schedule, title: title)
                systemAlarms[id] = scheduled
                lastErrors[id] = nil
                // The record may have been edited or deleted during the await;
                // confirmSchedule ignores a mismatch and the coalesced follow-up
                // pass reschedules with the latest state.
                if let current = try? fetchRecord(id) {
                    current.confirmSchedule(
                        schedule,
                        title: title,
                        at: now(),
                        presentationVersion: AlarmSyncPlanner.currentPresentationVersion
                    )
                    saveContext(recordingErrorFor: id)
                }
            } catch {
                lastErrors[id] = AlarmSchedulingError(error)
            }
        }
    }

    /// Single in-flight permission request shared by concurrent callers so
    /// rapid actions can't stack prompts.
    private func ensureAuthorized(prompt: Bool) async -> Bool {
        authorization = service.authorization
        switch authorization {
        case .authorized:
            return true
        case .denied:
            lastAuthorizationRequestError = nil
            return false
        case .notDetermined:
            guard prompt else { return false }
        }

        if let authorizationRequest {
            return await authorizationRequest.value == .authorized
        }
        let service = service
        let request = Task { @MainActor [weak self] () -> AlarmAuthorization in
            do {
                self?.lastAuthorizationRequestError = nil
                return try await service.requestAuthorization()
            } catch {
                self?.lastAuthorizationRequestError = AlarmSchedulingError(error)
                return service.authorization
            }
        }
        authorizationRequest = request
        let result = await request.value
        authorizationRequest = nil
        authorization = result
        return result == .authorized
    }

    @discardableResult
    private func refreshSystemAlarms(recordingErrorFor id: UUID? = nil) -> Bool {
        do {
            replaceSystemAlarms(try service.scheduledAlarms())
            return true
        } catch {
            if let id { lastErrors[id] = AlarmSchedulingError(error) }
            return false
        }
    }

    private func replaceSystemAlarms(_ alarms: [SystemAlarm]) {
        systemAlarms = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private func fetchRecord(_ id: UUID) throws -> AlarmRecord? {
        var descriptor = FetchDescriptor<AlarmRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func saveContext(recordingErrorFor id: UUID) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            lastErrors[id] = .persistenceFailed(error.localizedDescription)
        }
    }
}
