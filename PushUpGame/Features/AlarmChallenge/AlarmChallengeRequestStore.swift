//
//  AlarmChallengeRequestStore.swift
//  PushUpGame
//

import Foundation

/// A "Start Push-Ups" tap on an alarm alert that hasn't been shown yet.
nonisolated struct AlarmChallengeRequest: Codable, Equatable, Sendable {
    let alarmID: UUID
    let receivedAt: Date
}

/// Persists the most recent pending request between the alarm intent and the UI.
///
/// On a cold launch the intent can run before the scene and its model context
/// exist, so the request is written to disk first and consumed once the UI is
/// ready. Only one request is kept: a newer alarm tap supersedes an older one.
@MainActor
final class AlarmChallengeRequestStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "pendingAlarmChallengeRequest") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> AlarmChallengeRequest? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let request = try? JSONDecoder().decode(AlarmChallengeRequest.self, from: data) else {
            // Unreadable (e.g. written by a future format): drop it rather
            // than failing on every launch.
            clear()
            return nil
        }
        return request
    }

    func save(_ request: AlarmChallengeRequest) {
        guard let data = try? JSONEncoder().encode(request) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
