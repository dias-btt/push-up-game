//
//  AlarmsEmptyStateView.swift
//  PushUpGame
//

import SwiftUI

struct AlarmsEmptyStateView: View {
    let onAddAlarm: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Alarms", systemImage: "alarm")
        } description: {
            Text("Create an alarm and choose how many push-ups it takes to turn it off.")
        } actions: {
            Button("Add Alarm", action: onAddAlarm)
                .buttonStyle(.borderedProminent)
        }
    }
}
