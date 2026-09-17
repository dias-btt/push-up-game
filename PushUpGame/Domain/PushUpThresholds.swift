//
//  PushUpThresholds.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation

/// Tunable constants for push-up detection and pose analysis.
enum PushUpThresholds {
    /// Minimum joint confidence required to use shoulder, elbow, or wrist in arm-angle math.
    static let minimumArmJointConfidence: Float = 0.5

    /// Minimum joint confidence for shoulder, hip, and ankle when computing body-line angle.
    static let minimumBodyLineJointConfidence: Float = 0.5

    /// Exponential moving average weight for new elbow-angle samples.
    static let elbowSmoothingAlpha: Double = 0.4

    /// Number of recent per-side confidence samples used to pick the trusted side.
    static let confidenceWindowSize = 5

    /// Consecutive frames the alternate side must lead before switching trusted side.
    static let trustedSideSwitchFrameCount = 5
}
