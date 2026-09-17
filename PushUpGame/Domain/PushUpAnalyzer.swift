//
//  PushUpAnalyzer.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreGraphics
import Foundation

enum Side: Equatable, Sendable {
    case left
    case right
}

struct AnalyzedFrame: Equatable, Sendable {
    let leftElbowAngle: Double?
    let rightElbowAngle: Double?
    let bodyLineAngle: Double?
    let trustedSide: Side?
    let smoothedTrustedElbowAngle: Double?
    let poseValid: Bool
}

/// Synchronous per-frame pose analysis for push-up detection.
/// Caller is responsible for thread-safety if shared across contexts.
struct PushUpAnalyzer {
    private var leftSmoothedElbowAngle: Double?
    private var rightSmoothedElbowAngle: Double?
    private var leftConfidenceSamples: [Float] = []
    private var rightConfidenceSamples: [Float] = []
    private var trustedSide: Side?
    private var pendingTrustedSide: Side?
    private var consecutiveFramesFavoringPendingSide = 0

    mutating func process(_ pose: BodyPose, at timestamp: Date) -> AnalyzedFrame {
        _ = timestamp

        let leftArm = armMetrics(for: .left, in: pose)
        let rightArm = armMetrics(for: .right, in: pose)

        if let leftArm {
            appendConfidenceSample(leftArm.averageConfidence, to: &leftConfidenceSamples)
            leftSmoothedElbowAngle = smooth(
                raw: leftArm.elbowAngle,
                previous: leftSmoothedElbowAngle
            )
        }

        if let rightArm {
            appendConfidenceSample(rightArm.averageConfidence, to: &rightConfidenceSamples)
            rightSmoothedElbowAngle = smooth(
                raw: rightArm.elbowAngle,
                previous: rightSmoothedElbowAngle
            )
        }

        updateTrustedSide()

        let bodyLineAngle = bodyLineAngle(for: trustedSide, in: pose)
            ?? bodyLineAngle(for: .left, in: pose)
            ?? bodyLineAngle(for: .right, in: pose)

        let poseValid = leftArm != nil || rightArm != nil
        let smoothedTrustedElbowAngle = smoothedElbowAngle(for: trustedSide)

        return AnalyzedFrame(
            leftElbowAngle: leftArm?.elbowAngle,
            rightElbowAngle: rightArm?.elbowAngle,
            bodyLineAngle: bodyLineAngle,
            trustedSide: trustedSide,
            smoothedTrustedElbowAngle: smoothedTrustedElbowAngle,
            poseValid: poseValid
        )
    }

    // MARK: - Arm metrics

    private struct ArmMetrics {
        let elbowAngle: Double
        let averageConfidence: Float
    }

    private func armMetrics(for side: Side, in pose: BodyPose) -> ArmMetrics? {
        let joints = armJoints(for: side)
        guard
            let shoulder = pose.joints[joints.shoulder],
            let elbow = pose.joints[joints.elbow],
            let wrist = pose.joints[joints.wrist],
            shoulder.confidence >= PushUpThresholds.minimumArmJointConfidence,
            elbow.confidence >= PushUpThresholds.minimumArmJointConfidence,
            wrist.confidence >= PushUpThresholds.minimumArmJointConfidence
        else {
            return nil
        }

        let elbowAngle = angle(
            at: elbow.location,
            between: shoulder.location,
            and: wrist.location
        )
        let averageConfidence = (shoulder.confidence + elbow.confidence + wrist.confidence) / 3
        return ArmMetrics(elbowAngle: elbowAngle, averageConfidence: averageConfidence)
    }

    private func bodyLineAngle(for side: Side?, in pose: BodyPose) -> Double? {
        guard let side else { return nil }

        let joints = bodyLineJoints(for: side)
        guard
            let shoulder = pose.joints[joints.shoulder],
            let hip = pose.joints[joints.hip],
            let ankle = pose.joints[joints.ankle],
            shoulder.confidence >= PushUpThresholds.minimumBodyLineJointConfidence,
            hip.confidence >= PushUpThresholds.minimumBodyLineJointConfidence,
            ankle.confidence >= PushUpThresholds.minimumBodyLineJointConfidence
        else {
            return nil
        }

        return angle(
            at: hip.location,
            between: shoulder.location,
            and: ankle.location
        )
    }

    private func armJoints(for side: Side) -> (shoulder: BodyJoint, elbow: BodyJoint, wrist: BodyJoint) {
        switch side {
        case .left:
            return (.leftShoulder, .leftElbow, .leftWrist)
        case .right:
            return (.rightShoulder, .rightElbow, .rightWrist)
        }
    }

    private func bodyLineJoints(for side: Side) -> (shoulder: BodyJoint, hip: BodyJoint, ankle: BodyJoint) {
        switch side {
        case .left:
            return (.leftShoulder, .leftHip, .leftAnkle)
        case .right:
            return (.rightShoulder, .rightHip, .rightAnkle)
        }
    }

    // MARK: - Smoothing

    private func smooth(raw: Double, previous: Double?) -> Double {
        guard let previous else { return raw }
        let alpha = PushUpThresholds.elbowSmoothingAlpha
        return alpha * raw + (1 - alpha) * previous
    }

    private func smoothedElbowAngle(for side: Side?) -> Double? {
        switch side {
        case .left:
            return leftSmoothedElbowAngle
        case .right:
            return rightSmoothedElbowAngle
        case nil:
            return nil
        }
    }

    // MARK: - Trusted side

    private func appendConfidenceSample(_ sample: Float, to window: inout [Float]) {
        window.append(sample)
        if window.count > PushUpThresholds.confidenceWindowSize {
            window.removeFirst(window.count - PushUpThresholds.confidenceWindowSize)
        }
    }

    private mutating func updateTrustedSide() {
        let leftAverage = averageConfidence(leftConfidenceSamples)
        let rightAverage = averageConfidence(rightConfidenceSamples)

        let favoredSide: Side?
        if leftAverage == nil, rightAverage == nil {
            favoredSide = nil
        } else if let leftAverage, let rightAverage {
            favoredSide = leftAverage >= rightAverage ? .left : .right
        } else if leftAverage != nil {
            favoredSide = .left
        } else {
            favoredSide = .right
        }

        guard let favoredSide else {
            trustedSide = nil
            pendingTrustedSide = nil
            consecutiveFramesFavoringPendingSide = 0
            return
        }

        if trustedSide == nil {
            trustedSide = favoredSide
            pendingTrustedSide = nil
            consecutiveFramesFavoringPendingSide = 0
            return
        }

        if favoredSide == trustedSide {
            pendingTrustedSide = nil
            consecutiveFramesFavoringPendingSide = 0
            return
        }

        if favoredSide == pendingTrustedSide {
            consecutiveFramesFavoringPendingSide += 1
        } else {
            pendingTrustedSide = favoredSide
            consecutiveFramesFavoringPendingSide = 1
        }

        if consecutiveFramesFavoringPendingSide >= PushUpThresholds.trustedSideSwitchFrameCount {
            trustedSide = favoredSide
            pendingTrustedSide = nil
            consecutiveFramesFavoringPendingSide = 0
        }
    }

    private func averageConfidence(_ samples: [Float]) -> Float? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(Float(0), +)
        return total / Float(samples.count)
    }
}
