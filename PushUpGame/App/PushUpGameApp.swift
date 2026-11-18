//
//  PushUpGameApp.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import SwiftData
import SwiftUI

@main
struct PushUpGameApp: App {
    /// Created once at launch. A failure (e.g. corrupt store, full disk) is shown
    /// to the user instead of crashing on launch.
    private let environment = Result { try AppDependencies.makeAppEnvironment() }

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .success(let environment):
                AppRootView(alarmCoordinator: environment.alarmCoordinator)
                    .modelContainer(environment.modelContainer)
            case .failure(let error):
                StorageUnavailableView(error: error)
            }
        }
    }
}
