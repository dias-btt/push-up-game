//
//  AlarmChallenge.swift
//  PushUpGame
//

import Foundation

/// What the user must do to finish an alarm: the snapshot shown on the
/// challenge screen, resolved from the stored alarm by its stable ID.
nonisolated struct AlarmChallenge: Equatable, Hashable, Sendable {
    let alarmID: UUID
    let title: String
    let pushUpTarget: Int
}
