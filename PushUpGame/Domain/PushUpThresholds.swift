//
//  PushUpThresholds.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation

/// Tunable detection constants for push-up analysis and rep counting.
/// Adjust these values during on-device tuning; tests rely on the defaults below.
enum PushUpThresholds {
    // MARK: - Elbow angle (degrees)

    /// Elbow angle at or above this value is treated as the top / extended position.
    static let upThresholdDegrees: Double = 155

    /// Elbow angle must fall below this value (sustained) to register the bottom position.
    static let downThresholdDegrees: Double = 95

    /// Hysteresis band applied around up/down thresholds to reduce threshold chatter.
    static let hysteresisBandDegrees: Double = 8

    // MARK: - Timing (seconds)

    /// How long an angle must remain past a threshold before the state advances.
    static let minSustainDuration: TimeInterval = 0.15

    /// Minimum full-cycle duration from descent start to rep completion.
    static let minRepDuration: TimeInterval = 0.6

    /// How long invalid pose data is tolerated before resetting to `.unknown`.
    static let lostTrackingGraceDuration: TimeInterval = 0.5
}
