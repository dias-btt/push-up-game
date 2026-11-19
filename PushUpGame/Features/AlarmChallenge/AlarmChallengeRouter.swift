//
//  AlarmChallengeRouter.swift
//  PushUpGame
//

import Foundation
import Observation

/// Routes "Start Push-Ups" taps from the alarm alert to the challenge screen.
///
/// **Handoff.** `StartPushUpChallengeIntent` calls `receive(alarmID:)`, which
/// persists the request before anything else. The UI calls `activate(resolver:)`
/// once its model context exists; whichever happens second delivers the request.
/// This covers both an already-running app and a cold launch, where the intent
/// may run before the scene is set up.
///
/// **At most once.** A request is removed from the store before it is acted on,
/// and a repeat delivery for the alarm already on screen (or handled moments
/// ago) is ignored, so the same tap never pushes the challenge twice.
@MainActor
@Observable
final class AlarmChallengeRouter {
    /// Requests older than this are dropped instead of opening a challenge
    /// long after the alarm, e.g. if the app was killed before showing it and
    /// only relaunched hours later.
    static let requestLifetime: TimeInterval = 10 * 60
    /// The system may deliver the same tap more than once. A real second ring
    /// of the same alarm is at least a minute later, so this window never
    /// swallows a legitimate request.
    static let duplicateWindow: TimeInterval = 60

    /// The home navigation stack.
    var path: [HomeRoute] = []
    /// Set when a tap referenced an alarm that no longer exists.
    var isShowingUnavailableAlarmNotice = false

    @ObservationIgnored private let store: AlarmChallengeRequestStore
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var resolveChallenge: ((UUID) -> AlarmChallenge?)?
    @ObservationIgnored private var lastHandledRequest: AlarmChallengeRequest?

    init(store: AlarmChallengeRequestStore, now: @escaping () -> Date = { .now }) {
        self.store = store
        self.now = now
    }

    /// The alarm whose challenge is currently on screen, if any.
    var activeChallengeID: UUID? {
        path.last?.alarmChallengeID
    }

    /// Entry point for the alarm alert's "Start Push-Ups" action.
    func receive(alarmID: UUID) {
        store.save(AlarmChallengeRequest(alarmID: alarmID, receivedAt: now()))
        deliverPendingRequest()
    }

    /// Called once the UI can look alarms up. Delivers any request that
    /// arrived earlier, including one persisted before a cold launch.
    func activate(resolver: @escaping (UUID) -> AlarmChallenge?) {
        resolveChallenge = resolver
        deliverPendingRequest()
    }

    /// Shows the pending request, if any. Safe to call repeatedly (e.g. on
    /// every return to the foreground).
    func deliverPendingRequest() {
        guard let resolveChallenge, let request = store.load() else { return }
        // Consume first so a crash or relaunch can't replay it.
        store.clear()

        guard now().timeIntervalSince(request.receivedAt) <= Self.requestLifetime,
              !isDuplicate(request) else {
            return
        }
        lastHandledRequest = request

        guard resolveChallenge(request.alarmID) != nil else {
            isShowingUnavailableAlarmNotice = true
            return
        }
        // Replace the stack: the alarm takes priority over a practice
        // workout or another alarm's challenge, and Back leads home.
        path = [.alarmChallenge(request.alarmID)]
    }

    /// Returns to the home screen. A no-op if no challenge is shown.
    func dismissChallenge() {
        path.removeAll { $0.alarmChallengeID != nil }
    }

    private func isDuplicate(_ request: AlarmChallengeRequest) -> Bool {
        if path.contains(.alarmChallenge(request.alarmID)) {
            return true
        }
        guard let lastHandledRequest, lastHandledRequest.alarmID == request.alarmID else {
            return false
        }
        return abs(request.receivedAt.timeIntervalSince(lastHandledRequest.receivedAt)) < Self.duplicateWindow
    }
}
