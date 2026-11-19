//
//  SchedulingStatusView.swift
//  PushUpGame
//

import SwiftUI

/// Per-alarm system state, with a Retry action when retrying can help.
struct SchedulingStatusView: View {
    let status: AlarmSchedulingStatus
    let onRetry: () -> Void

    var body: some View {
        switch status {
        case .off:
            Label("Off", systemImage: "bell.slash")
                .foregroundStyle(.secondary)
        case .updating:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Updating…")
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        case .scheduled:
            Label("Scheduled", systemImage: "bell.fill")
                .foregroundStyle(.green)
        case .permissionRequired:
            Label("Permission required", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .notScheduled:
            HStack(spacing: 8) {
                Label("Not scheduled", systemImage: "bell.badge.slash")
                    .foregroundStyle(.secondary)
                retryButton
            }
        case .failed(let error):
            VStack(alignment: .leading, spacing: 4) {
                Label("Scheduling failed", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if error.isRetryable {
                    retryButton
                }
            }
        }
    }

    private var retryButton: some View {
        Button("Retry", action: onRetry)
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .accessibilityHint("Tries to schedule this alarm again")
    }
}
