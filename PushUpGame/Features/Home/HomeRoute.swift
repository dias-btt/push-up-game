//
//  HomeRoute.swift
//  PushUpGame
//

import Foundation

/// Destinations pushed onto the home navigation stack.
enum HomeRoute: Hashable {
    case manualWorkout
    case alarmChallenge(UUID)

    var alarmChallengeID: UUID? {
        guard case .alarmChallenge(let id) = self else { return nil }
        return id
    }
}
