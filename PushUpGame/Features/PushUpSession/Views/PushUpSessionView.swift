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

            VStack {
                Text("Reps: \(viewModel.repCount)")
                    .font(.title)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.switchCamera() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title2)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Switch camera")
                }
                Spacer()
            }
            .padding()
        }
        .task {
            captureSession = await viewModel.captureSession()
            await viewModel.startSession()
        }
        .onDisappear {
            Task { await viewModel.stopSession() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await viewModel.startSession() }
            case .background:
                Task { await viewModel.stopSession() }
            default:
                break
            }
        }
    }
}
