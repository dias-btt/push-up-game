//
//  PushUpGameApp.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import SwiftUI

@main
struct PushUpGameApp: App {
    @State private var viewModel = AppDependencies.makePushUpSessionViewModel()

    var body: some Scene {
        WindowGroup {
            PushUpSessionView(viewModel: viewModel)
        }
    }
}
