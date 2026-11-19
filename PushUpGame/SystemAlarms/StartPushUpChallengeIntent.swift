//
//  StartPushUpChallengeIntent.swift
//  PushUpGame
//

import AlarmKit
import AppIntents
import Foundation

/// The alarm alert's "Start Push-Ups" button.
///
/// Follows Apple's AlarmKit sample: a `LiveActivityIntent` (the type AlarmKit
/// accepts as a secondary intent) with `openAppWhenRun`, so it runs in the app's
/// process and brings the app to the foreground, launching it if needed. The
/// alarm is identified by its stable ID, the same UUID used for the stored
/// record and the system alarm.
nonisolated struct StartPushUpChallengeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Push-Ups"
    static let description: IntentDescription? = IntentDescription("Opens the push-up challenge for a ringing alarm.")
    static let openAppWhenRun = true
    /// Only meaningful from an alarm alert, so it isn't offered in Shortcuts.
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    @Dependency
    private var router: AlarmChallengeRouter

    init() {}

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        // Hand off first: the router persists the request, so it survives
        // even if the UI isn't ready yet on a cold launch.
        router.receive(alarmID: id)
        // Silence the alert now that the user is in the app, as Apple's sample
        // does. A one-time alarm is then removed by the system and turned off by
        // the next reconciliation; a repeating one rings again next time.
        try? AlarmManager.shared.stop(id: id)
        return .result()
    }
}
