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

    /// Long-lived objects created once at launch.
    struct AppEnvironment {
        let modelContainer: ModelContainer
        let alarmCoordinator: AlarmScheduleCoordinator
    }

    @MainActor
    static func makeAppEnvironment() throws -> AppEnvironment {
        let container = try makeModelContainer()
        let coordinator = AlarmScheduleCoordinator(
            service: AlarmKitService(),
            modelContext: container.mainContext
        )
        return AppEnvironment(modelContainer: container, alarmCoordinator: coordinator)
    }

    /// Independent of the model container so the alarm intent can always be
    /// delivered, even if storage failed to load.
    @MainActor
    static func makeAlarmChallengeRouter() -> AlarmChallengeRouter {
        AlarmChallengeRouter(store: AlarmChallengeRequestStore())
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
