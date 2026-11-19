//
//  PushUpGameApp.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AppIntents
import SwiftData
import SwiftUI

@main
struct PushUpGameApp: App {
    /// Created once at launch. A failure (e.g. corrupt store, full disk) is shown
    /// to the user instead of crashing on launch.
    private let environment = Result { try AppDependencies.makeAppEnvironment() }
    private let challengeRouter: AlarmChallengeRouter

    init() {
        let router = AppDependencies.makeAlarmChallengeRouter()
        // Registered at launch, before the system performs a pending intent,
        // so a cold launch from the alarm alert can reach the router.
        AppDependencyManager.shared.add(dependency: router)
        challengeRouter = router
    }

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .success(let environment):
                AppRootView(
                    alarmCoordinator: environment.alarmCoordinator,
                    challengeRouter: challengeRouter
                )
                .modelContainer(environment.modelContainer)
            case .failure(let error):
                StorageUnavailableView(error: error)
            }
        }
    }
}
