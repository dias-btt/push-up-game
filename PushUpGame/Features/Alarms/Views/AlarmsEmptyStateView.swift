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

/// Explains that alarms are saved but cannot ring yet. Shown until system
/// scheduling ships so the list never suggests the alarms are live.
struct SchedulingNoticeView: View {
    var body: some View {
        Label(
            "Alarms are saved on this device but won't ring yet. Scheduling is coming in a later build.",
            systemImage: "info.circle"
        )
        .font(.footnote)
    }
}
