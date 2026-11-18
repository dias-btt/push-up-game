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
    private let modelContainer = Result { try AppDependencies.makeModelContainer() }

    var body: some Scene {
        WindowGroup {
            switch modelContainer {
            case .success(let container):
                HomeView()
                    .modelContainer(container)
            case .failure(let error):
                StorageUnavailableView(error: error)
            }
        }
    }
}
