//
//  BodyPose.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreGraphics

nonisolated enum BodyJoint: CaseIterable, Sendable, Hashable {
    case nose, leftEye, rightEye, leftEar, rightEar
    case neck, leftShoulder, rightShoulder, leftElbow, rightElbow
    case leftWrist, rightWrist, root, leftHip, rightHip
    case leftKnee, rightKnee, leftAnkle, rightAnkle
}

nonisolated struct BodyPose: Sendable {
    struct JointPoint: Sendable {
        let location: CGPoint // normalized 0-1, Vision's coordinate space
        let confidence: Float
    }

    let joints: [BodyJoint: JointPoint]
}
