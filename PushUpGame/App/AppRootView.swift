//
//  AppRootView.swift
//  PushUpGame
//

import SwiftUI

/// Hosts the home screen and drives alarm reconciliation at launch and on
/// every return to the foreground, which also picks up permission changes
/// made in Settings and alarms that rang while the app was suspended.
///
/// Also connects the alarm challenge router to the model context, which
/// releases any "Start Push-Ups" tap that arrived before the UI was ready.
struct AppRootView: View {
    let alarmCoordinator: AlarmScheduleCoordinator
    let challengeRouter: AlarmChallengeRouter

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HomeView()
            .environment(alarmCoordinator)
            .environment(challengeRouter)
            .task {
                let modelContext = modelContext
                challengeRouter.activate { AlarmRecord.challenge(for: $0, in: modelContext) }
                alarmCoordinator.startObserving()
                await alarmCoordinator.reconcileAll()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                challengeRouter.deliverPendingRequest()
                Task { await alarmCoordinator.reconcileAll() }
            }
    }
}
