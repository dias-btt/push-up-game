//
//  AlarmRowView.swift
//  PushUpGame
//

import SwiftUI

struct AlarmRowView: View {
    let alarm: AlarmRecord
    let status: AlarmSchedulingStatus
    let isUpdating: Bool
    let onEdit: () -> Void
    let onToggleEnabled: (Bool) -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: onEdit) {
                    details
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Edits this alarm")

                SchedulingStatusView(status: status, onRetry: onRetry)
                    .font(.caption)
            }

            Toggle(
                "Enabled",
                isOn: Binding(get: { alarm.isEnabled }, set: onToggleEnabled)
            )
            .labelsHidden()
            // The coordinator coalesces rapid changes anyway; disabling the
            // toggle mid-operation makes the in-flight state visible.
            .disabled(isUpdating)
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

            Label("\(alarm.pushUpTarget) push-ups", systemImage: "figure.strengthtraining.functional")
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
