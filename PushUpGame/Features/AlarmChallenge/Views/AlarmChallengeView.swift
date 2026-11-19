//
//  AlarmChallengeView.swift
//  PushUpGame
//

import SwiftData
import SwiftUI

/// Destination opened from an alarm's "Start Push-Ups" action.
///
/// Reads the alarm live by ID, so a deletion while the screen is open shows
/// an unavailable state instead of stale data. Rep counting is not connected
/// yet; progress always starts at zero.
struct AlarmChallengeView: View {
    let alarmID: UUID

    @Environment(AlarmChallengeRouter.self) private var router
    @Query private var matchingAlarms: [AlarmRecord]

    init(alarmID: UUID) {
        self.alarmID = alarmID
        _matchingAlarms = Query(filter: #Predicate<AlarmRecord> { $0.id == alarmID })
    }

    var body: some View {
        Group {
            if let challenge = matchingAlarms.first?.challenge {
                AlarmChallengeContentView(challenge: challenge, onReturnHome: router.dismissChallenge)
            } else {
                unavailableView
            }
        }
        .navigationTitle("Alarm Challenge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Alarm Not Found", systemImage: "alarm")
        } description: {
            Text("This alarm was deleted, so there's no challenge to start.")
        } actions: {
            Button("Back to Alarms", action: router.dismissChallenge)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct AlarmChallengeContentView: View {
    let challenge: AlarmChallenge
    let onReturnHome: () -> Void

    /// Always zero until the workout engine is connected.
    private let completedPushUps = 0
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Text(challenge.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("Complete \(challenge.pushUpTarget) push-ups")
                    .foregroundStyle(.secondary)
            }
            progressView
            Spacer()
            actions
        }
        .padding()
    }

    private var progressView: some View {
        VStack(spacing: 12) {
            Text("\(completedPushUps) / \(challenge.pushUpTarget)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("\(completedPushUps) of \(challenge.pushUpTarget) push-ups")
            ProgressView(value: Double(completedPushUps), total: Double(challenge.pushUpTarget))
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                hasStarted = true
            } label: {
                Text("Start Challenge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(hasStarted)

            if hasStarted {
                Text("Push-up counting for alarm challenges is coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Back to Alarms", action: onReturnHome)
        }
    }
}
