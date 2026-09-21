//
//  AppDependencies.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation

enum AppDependencies {
    @MainActor
    static func makePushUpSessionViewModel() -> PushUpSessionViewModel {
        let cameraService = AVFoundationCameraService()
        let poseDetectionService = VisionPoseDetectionService()
        let session = PushUpSession(
            cameraService: cameraService,
            poseDetectionService: poseDetectionService
        )
        return PushUpSessionViewModel(session: session)
    }
}
