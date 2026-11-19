//
//  AlarmSchedulingError.swift
//  PushUpGame
//

import Foundation

/// Whether the app may schedule system alarms. Mirrors the system states
/// without depending on the system framework.
nonisolated enum AlarmAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// Typed failures from the system alarm boundary, surfaced in the UI.
nonisolated enum AlarmSchedulingError: Error, Equatable, Sendable, LocalizedError {
    case notAuthorized
    case authorizationRequestFailed(String)
    case maximumLimitReached
    case systemFailure(String)
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "PushUpGame isn't allowed to schedule alarms. You can allow it in Settings."
        case .authorizationRequestFailed(let detail):
            return "Couldn't ask for alarm permission. \(detail)"
        case .maximumLimitReached:
            return "You've reached the system limit for alarms. Turn off or delete an alarm and try again."
        case .systemFailure(let detail):
            return "The system couldn't schedule this alarm. \(detail)"
        case .persistenceFailed(let detail):
            return "Couldn't save the alarm's state. \(detail)"
        }
    }

    /// Normalizes an error from the system boundary. Implementations throw
    /// `AlarmSchedulingError` already; anything else is wrapped.
    init(_ error: any Error) {
        self = error as? AlarmSchedulingError ?? .systemFailure(error.localizedDescription)
    }

    /// Whether retrying without user changes elsewhere could succeed.
    var isRetryable: Bool {
        switch self {
        case .notAuthorized, .maximumLimitReached:
            return false
        case .authorizationRequestFailed, .systemFailure, .persistenceFailed:
            return true
        }
    }
}
