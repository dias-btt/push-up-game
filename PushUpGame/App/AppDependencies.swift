//
//  AppDependencies.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation
import SwiftData

enum AppDependencies {
    /// Builds a fresh camera → pose → session graph. Call once per workout screen
    /// presentation: the session's frame/update streams are single-use, so reusing
    /// a view model after `stopSession()` would leave the camera running with no
    /// frames processed.
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

    static let persistentSchema = Schema([AlarmRecord.self])

    /// On-disk store for the app; tests pass `inMemory: true` for an isolated store
    /// with the same schema.
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: persistentSchema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: persistentSchema, configurations: configuration)
    }
}
