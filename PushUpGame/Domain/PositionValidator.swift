//
//  PositionValidator.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreGraphics
import Foundation

enum PositioningStatus: Equatable, Sendable {
    case noPersonDetected
    case tooFar
    case tooClose
    case partiallyOutOfFrame
    case checking
    case ready
}

/// Heuristic camera-positioning feedback from a single body pose sample.
struct PositionValidator {
    private var consecutiveReadyEvaluations = 0

    mutating func evaluate(_ pose: BodyPose?) -> PositioningStatus {
        guard let pose else {
            resetReadyDebounce()
            return .noPersonDetected
        }

        let confidentJoints = pose.joints.filter {
            $0.value.confidence >= PushUpThresholds.positioningMinimumJointConfidence
        }

        guard !confidentJoints.isEmpty else {
            resetReadyDebounce()
            return .noPersonDetected
        }

        guard hasRequiredBodyStructure(in: confidentJoints) else {
            resetReadyDebounce()
            return .noPersonDetected
        }

        if hasJointNearFrameEdge(in: confidentJoints) {
            resetReadyDebounce()
            return .partiallyOutOfFrame
        }

        let boundingBox = Self.boundingBox(for: confidentJoints)
        let area = Double(boundingBox.width * boundingBox.height)

        if area < PushUpThresholds.positioningMinimumBoundingBoxArea {
            resetReadyDebounce()
            return .tooFar
        }

        if area > PushUpThresholds.positioningMaximumBoundingBoxArea {
            resetReadyDebounce()
            return .tooClose
        }

        consecutiveReadyEvaluations += 1
        if consecutiveReadyEvaluations >= PushUpThresholds.positioningReadyFrameCount {
            return .ready
        }
        return .checking
    }

    private mutating func resetReadyDebounce() {
        consecutiveReadyEvaluations = 0
    }

    private func hasRequiredBodyStructure(in joints: [BodyJoint: BodyPose.JointPoint]) -> Bool {
        let hasLeftLeg = joints[.leftKnee] != nil || joints[.leftAnkle] != nil
        let hasRightLeg = joints[.rightKnee] != nil || joints[.rightAnkle] != nil

        return joints[.leftShoulder] != nil
            && joints[.rightShoulder] != nil
            && joints[.leftHip] != nil
            && joints[.rightHip] != nil
            && hasLeftLeg
            && hasRightLeg
    }

    private func hasJointNearFrameEdge(in joints: [BodyJoint: BodyPose.JointPoint]) -> Bool {
        let margin = PushUpThresholds.positioningFrameEdgeMargin
        for point in joints.values {
            let location = point.location
            if location.x <= margin
                || location.x >= 1 - margin
                || location.y <= margin
                || location.y >= 1 - margin
            {
                return true
            }
        }
        return false
    }

    private static func boundingBox(for joints: [BodyJoint: BodyPose.JointPoint]) -> CGRect {
        let locations = joints.values.map(\.location)
        guard let first = locations.first else { return .zero }

        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for location in locations.dropFirst() {
            minX = min(minX, location.x)
            maxX = max(maxX, location.x)
            minY = min(minY, location.y)
            maxY = max(maxY, location.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
