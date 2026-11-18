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
    private(set) var framesInCurrentState = 0
    private(set) var lastCompletedRepDuration: TimeInterval?

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
        let stateAtStart = state

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
                let event = PushUpEvent.positionInvalid(reason: "Pose tracking unavailable")
                finishTick(startedIn: stateAtStart)
                return event
            }
            finishTick(startedIn: stateAtStart)
            return nil
        }

        trackingLostSince = nil
        let minSustainFrames = Self.minimumSustainFrames(for: framesPerSecond)

        let event: PushUpEvent?
        switch state {
        case .unknown:
            if elbowAngle >= PushUpThresholds.upThresholdDegrees {
                state = .ready
                event = .stateChanged(to: .ready)
            } else {
                event = nil
            }

        case .ready, .up:
            if elbowAngle <= PushUpThresholds.downThresholdDegrees + PushUpThresholds.hysteresisBandDegrees {
                beginCycle(at: now)
                state = .descending
                event = .stateChanged(to: .descending)
            } else {
                event = nil
            }

        case .descending:
            if elbowAngle >= PushUpThresholds.upThresholdDegrees {
                resetCycleTracking()
                state = .up
                event = .stateChanged(to: .up)
            } else if elbowAngle < PushUpThresholds.downThresholdDegrees {
                descendingSustainFrameCount += 1
                if descendingSustainFrameCount >= minSustainFrames {
                    descendingSustainFrameCount = 0
                    reachedDownThisCycle = true
                    state = .down
                    event = .stateChanged(to: .down)
                } else {
                    event = nil
                }
            } else {
                descendingSustainFrameCount = 0
                event = nil
            }

        case .down:
            if elbowAngle >= PushUpThresholds.upThresholdDegrees - PushUpThresholds.hysteresisBandDegrees {
                ascendingSustainFrameCount = 0
                state = .ascending
                event = .stateChanged(to: .ascending)
            } else {
                event = nil
            }

        case .ascending:
            if elbowAngle <= PushUpThresholds.downThresholdDegrees {
                ascendingSustainFrameCount = 0
                state = .down
                event = .stateChanged(to: .down)
            } else if elbowAngle >= PushUpThresholds.upThresholdDegrees {
                ascendingSustainFrameCount += 1
                if ascendingSustainFrameCount >= minSustainFrames {
                    ascendingSustainFrameCount = 0
                    let cycleDuration = cycleStartTime.map { now.timeIntervalSince($0) } ?? 0
                    state = .up

                    if reachedDownThisCycle, cycleDuration >= PushUpThresholds.minRepDuration {
                        repCount += 1
                        lastCompletedRepDuration = cycleDuration
                        resetCycleTracking()
                        event = .repCompleted
                    } else {
                        resetCycleTracking()
                        event = .stateChanged(to: .up)
                    }
                } else {
                    event = nil
                }
            } else {
                ascendingSustainFrameCount = 0
                event = nil
            }
        }

        finishTick(startedIn: stateAtStart)
        return event
    }

    private mutating func finishTick(startedIn: PushUpState) {
        if state == startedIn {
            framesInCurrentState += 1
        } else {
            framesInCurrentState = 1
        }
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
