//
//  AppRootView.swift
//  PushUpGame
//

import SwiftUI

/// Hosts the home screen and drives alarm reconciliation at launch and on
/// every return to the foreground, which also picks up permission changes
/// made in Settings and alarms that rang while the app was suspended.
struct AppRootView: View {
    let alarmCoordinator: AlarmScheduleCoordinator

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HomeView()
            .environment(alarmCoordinator)
            .task {
                alarmCoordinator.startObserving()
                await alarmCoordinator.reconcileAll()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await alarmCoordinator.reconcileAll() }
            }
    }
}
