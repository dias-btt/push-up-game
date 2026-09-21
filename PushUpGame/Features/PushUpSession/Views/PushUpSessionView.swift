//
//  PushUpSessionView.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import SwiftUI

struct PushUpSessionView: View {
    @Bindable var viewModel: PushUpSessionViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var captureSession: AVCaptureSession?
    @State private var isDebugOverlayVisible = false

    var body: some View {
        ZStack {
            if let captureSession {
                CameraPreviewView(session: captureSession, cameraPosition: viewModel.cameraPosition)
                    .ignoresSafeArea()
            }

            GeometryReader { geometry in
                if let latestPose = viewModel.latestPose {
                    SkeletonOverlayView(
                        pose: latestPose,
                        orientedImageSize: viewModel.orientedImageSize,
                        size: geometry.size
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if viewModel.isWorkoutActive {
                workoutOverlay
            } else {
                PositioningGuideView(status: viewModel.positioningStatus) {
                    Task { await viewModel.beginWorkout() }
                }
            }

            if isDebugOverlayVisible {
                VStack {
                    HStack {
                        debugMetricsPanel
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 56)
                .padding(.horizontal)
            }

            chromeControls
        }
        .task {
            captureSession = await viewModel.captureSession()
            await viewModel.startPositioning()
        }
        .onDisappear {
            Task { await viewModel.stopSession() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await viewModel.startPositioning() }
            case .background:
                Task { await viewModel.stopSession() }
            default:
                break
            }
        }
    }

    private var chromeControls: some View {
        VStack {
            HStack(spacing: 12) {
                #if DEBUG
                Button {
                    isDebugOverlayVisible.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isDebugOverlayVisible ? .primary : .secondary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Toggle debug metrics")
                #endif

                Spacer()

                Button {
                    Task { await viewModel.switchCamera() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Switch camera")
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var workoutOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 14) {
                phaseIndicator

                Text("PUSH-UPS: \(viewModel.repCount)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.42))
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var phaseIndicator: some View {
        let presentation = WorkoutPhasePresentation(for: viewModel.currentState)

        return HStack(spacing: 10) {
            Circle()
                .fill(presentation.tint)
                .frame(width: 12, height: 12)
                .shadow(color: presentation.tint.opacity(0.6), radius: 4)

            Text(presentation.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Phase \(presentation.label)")
    }

    private var debugMetricsPanel: some View {
        DebugMetricsPanel(
            analysisFPS: viewModel.analysisFPS,
            analyzedFrame: viewModel.latestAnalyzedFrame,
            currentState: viewModel.currentState,
            framesInCurrentState: viewModel.framesInCurrentState,
            repCount: viewModel.repCount,
            lastRepDuration: viewModel.lastRepDuration,
            isCSVLoggingEnabled: {
                #if DEBUG
                return viewModel.isCSVLoggingEnabled
                #else
                return false
                #endif
            }(),
            onToggleCSVLogging: { enabled in
                #if DEBUG
                viewModel.setCSVLoggingEnabled(enabled)
                #endif
            }
        )
    }
}

/// Maps internal rep-counting states to short, user-facing labels for the HUD.
private struct WorkoutPhasePresentation {
    let label: String
    let tint: Color

    init(for state: PushUpState) {
        switch state {
        case .up, .ready:
            label = "UP"
            tint = .green
        case .down:
            label = "DOWN"
            tint = .orange
        case .descending, .ascending:
            label = "···"
            tint = .yellow
        case .unknown:
            label = "—"
            tint = .gray
        }
    }
}
