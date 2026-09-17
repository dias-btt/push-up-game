//
//  PoseDetectionService.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreVideo
import ImageIO

/// Pose detection over a single camera frame.
/// Marked `nonisolated` so it is not inferred as `@MainActor` under
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
nonisolated protocol PoseDetectionService: Sendable {
    func detectPose(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> BodyPose?
}
