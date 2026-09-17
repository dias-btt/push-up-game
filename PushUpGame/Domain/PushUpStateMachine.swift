//
//  PushUpStateMachine.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation

/// Rep-counting state machine driven by smoothed elbow angle samples.
struct PushUpStateMachine {
    private(set) var state: PushUpState = .unknown
    private(set) var repCount = 0

    private var cycleStartTime: Date?
    private var reachedDownThisCycle = false
    private var trackingLostSince: Date?
    private var descendingSustainFrameCount = 0
    private var ascendingSustainFrameCount = 0

    mutating func update(
        elbowAngle: Double?,
        poseValid: Bool,
        now: Date,
        framesPerSecond: Double
    ) -> PushUpEvent? {
        guard poseValid, let elbowAngle else {
            if trackingLostSince == nil {
                trackingLostSince = now
            }

            if
                let lostSince = trackingLostSince,
                now.timeIntervalSince(lostSince) >= PushUpThresholds.lostTrackingGraceDuration,
                state != .unknown
            {
                resetCycleTracking()
                state = .unknown
                self.trackingLostSince = nil
                return .positionInvalid(reason: "Pose tracking unavailable")
            }
            return nil
        }

        trackingLostSince = nil
        let minSustainFrames = Self.minimumSustainFrames(for: framesPerSecond)

        switch state {
        case .unknown:
            if elbowAngle >= PushUpThresholds.upThresholdDegrees {
                state = .ready
                return .stateChanged(to: .ready)
            }

        case .ready, .up:
            if elbowAngle <= PushUpThresholds.downThresholdDegrees + PushUpThresholds.hysteresisBandDegrees {
                beginCycle(at: now)
                state = .descending
                return .stateChanged(to: .descending)
            }

        case .descending:
            if elbowAngle >= PushUpThresholds.upThresholdDegrees {
                resetCycleTracking()
                state = .up
                return .stateChanged(to: .up)
            }

            if elbowAngle < PushUpThresholds.downThresholdDegrees {
                descendingSustainFrameCount += 1
                if descendingSustainFrameCount >= minSustainFrames {
                    descendingSustainFrameCount = 0
                    reachedDownThisCycle = true
                    state = .down
                    return .stateChanged(to: .down)
                }
            } else {
                descendingSustainFrameCount = 0
            }

        case .down:
            if elbowAngle >= PushUpThresholds.upThresholdDegrees - PushUpThresholds.hysteresisBandDegrees {
                ascendingSustainFrameCount = 0
                state = .ascending
                return .stateChanged(to: .ascending)
            }

        case .ascending:
            if elbowAngle <= PushUpThresholds.downThresholdDegrees {
                ascendingSustainFrameCount = 0
                state = .down
                return .stateChanged(to: .down)
            }

            if elbowAngle >= PushUpThresholds.upThresholdDegrees {
                ascendingSustainFrameCount += 1
                if ascendingSustainFrameCount >= minSustainFrames {
                    ascendingSustainFrameCount = 0
                    let cycleDuration = cycleStartTime.map { now.timeIntervalSince($0) } ?? 0
                    state = .up

                    if reachedDownThisCycle, cycleDuration >= PushUpThresholds.minRepDuration {
                        repCount += 1
                        resetCycleTracking()
                        return .repCompleted
                    }

                    resetCycleTracking()
                    return .stateChanged(to: .up)
                }
            } else {
                ascendingSustainFrameCount = 0
            }
        }

        return nil
    }

    private mutating func beginCycle(at now: Date) {
        cycleStartTime = now
        reachedDownThisCycle = false
        descendingSustainFrameCount = 0
        ascendingSustainFrameCount = 0
    }

    private mutating func resetCycleTracking() {
        cycleStartTime = nil
        reachedDownThisCycle = false
        descendingSustainFrameCount = 0
        ascendingSustainFrameCount = 0
    }

    private static func minimumSustainFrames(for framesPerSecond: Double) -> Int {
        guard framesPerSecond > 0 else { return 1 }
        let frames = PushUpThresholds.minSustainDuration * framesPerSecond
        return max(1, Int(frames.rounded(.up)))
    }
}
