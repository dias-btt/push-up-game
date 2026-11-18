//
//  AlarmRowView.swift
//  PushUpGame
//

import SwiftUI

struct AlarmRowView: View {
    let alarm: AlarmRecord
    let onEdit: () -> Void
    let onToggleEnabled: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onEdit) {
                details
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edits this alarm")

            Toggle(
                "Enabled",
                isOn: Binding(get: { alarm.isEnabled }, set: onToggleEnabled)
            )
            .labelsHidden()
            .accessibilityLabel("\(configuration.displayTitle) enabled")
        }
        .padding(.vertical, 4)
    }

    private var configuration: AlarmConfiguration { alarm.configuration }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            AlarmTimeText(time: alarm.time)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(alarm.isEnabled ? .primary : .secondary)

            Text("\(configuration.displayTitle) · \(alarm.repeatDays.summary(calendar: .current))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label("\(alarm.pushUpTarget) push-ups", systemImage: "figure.strengthtraining.functional")
                SchedulingStatusLabel(status: alarm.schedulingStatus)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Formats an `AlarmTime` using the user's 12/24-hour preference.
struct AlarmTimeText: View {
    let time: AlarmTime

    var body: some View {
        if let date = time.date(onSameDayAs: .now, calendar: .current) {
            Text(date, format: .dateTime.hour().minute())
        } else {
            // Only reachable if today's DST transition skips this wall-clock time.
            Text(String(format: "%02d:%02d", time.hour, time.minute))
        }
    }
}

struct SchedulingStatusLabel: View {
    let status: AlarmSchedulingStatus

    var body: some View {
        switch status {
        case .off:
            Label("Off", systemImage: "bell.slash")
        case .notScheduled:
            Label("Not scheduled", systemImage: "bell.badge.slash")
        }
    }
}
