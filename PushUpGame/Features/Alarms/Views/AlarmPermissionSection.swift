//
//  AlarmPermissionSection.swift
//  PushUpGame
//

import SwiftUI
import UIKit

/// Shown only when enabled alarms exist but can't ring for lack of permission.
/// Offers the prompt when it hasn't been shown yet, or a path to Settings
/// once the user has denied it (the system won't prompt twice).
struct AlarmPermissionSection: View {
    let authorization: AlarmAuthorization
    let hasEnabledAlarms: Bool
    let onRequestPermission: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        if hasEnabledAlarms, authorization != .authorized {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(title, systemImage: "alarm.waves.left.and.right")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    actionButton
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var title: String {
        authorization == .denied ? "Alarms Are Turned Off" : "Allow Alarms"
    }

    private var message: String {
        authorization == .denied
            ? "PushUpGame isn't allowed to schedule alarms, so your alarms won't ring. Turn on Alarms for PushUpGame in Settings."
            : "PushUpGame needs permission to schedule alarms that ring even in Silent mode or Focus."
    }

    @ViewBuilder
    private var actionButton: some View {
        if authorization == .denied {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button("Allow Alarms", action: onRequestPermission)
                .buttonStyle(.borderedProminent)
        }
    }
}
