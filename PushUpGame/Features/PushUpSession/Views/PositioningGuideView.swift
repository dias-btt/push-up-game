//
//  PositioningGuideView.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import SwiftUI

struct PositioningGuideView: View {
    let status: PositioningStatus
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Text("Get in position")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.45))
            )

            Button(action: onStart) {
                Text("Start")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(status == .ready ? .green : .accentColor)
            .accessibilityHint("Starts counting push-ups. You can start even if positioning is not perfect.")

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var message: String {
        switch status {
        case .noPersonDetected:
            return "No person detected"
        case .tooFar:
            return "Move farther away"
        case .tooClose:
            return "Move closer"
        case .partiallyOutOfFrame:
            return "Make sure your whole body is visible"
        case .checking:
            return "Hold still, checking..."
        case .ready:
            return "Ready!"
        }
    }
}
