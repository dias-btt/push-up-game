//
//  PushUpSessionView.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import os
import SwiftUI

struct PushUpSessionView: View {
    // TODO: replace with injected PushUpSession in Step 9
    @State private var service = AVFoundationCameraService()
    @State private var latestPose: BodyPose?
    @State private var orientedImageSize = CGSize(width: 9, height: 16)

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            CameraPreviewView(session: service.session)
                .ignoresSafeArea()

            GeometryReader { geometry in
                if let latestPose {
                    SkeletonOverlayView(
                        pose: latestPose,
                        orientedImageSize: orientedImageSize,
                        size: geometry.size
                    )
                }
            }
            .ignoresSafeArea()
        }
        .task {
            await startCamera()
            // TODO: move frame → pose detection wiring into PushUpSession in Step 9
            await runTemporaryPoseDetectionLogger(
                frames: service.frames,
                cameraPosition: service.cameraPosition,
                onPoseUpdate: { pose, imageSize in
                    latestPose = pose
                    orientedImageSize = imageSize
                }
            )
        }
        .onDisappear {
            Task {
                await service.stop()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await startCamera() }
            case .background:
                Task { await service.stop() }
            default:
                break
            }
        }
    }

    private func startCamera() async {
        do {
            try await service.start()
        } catch {
            print("Camera start failed: \(error.localizedDescription)")
        }
    }
}

/// Temporary harness: consume camera frames, log pose stats, and publish the latest pose for the overlay.
/// TODO: move frame → pose detection wiring into PushUpSession in Step 9
@concurrent
nonisolated func runTemporaryPoseDetectionLogger(
    frames: AsyncStream<CVPixelBuffer>,
    cameraPosition: AVCaptureDevice.Position,
    onPoseUpdate: @escaping @MainActor (BodyPose?, CGSize) -> Void
) async {
    let poseService = VisionPoseDetectionService()
    let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PushUpGame",
        category: "PoseDetection"
    )

    await MainActor.run {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    defer {
        Task { @MainActor in
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    for await pixelBuffer in frames {
        let orientation = await MainActor.run {
            CGImagePropertyOrientation(
                deviceOrientation: UIDevice.current.orientation,
                cameraPosition: cameraPosition
            )
        }
        let imageSize = orientation.orientedImageSize(for: pixelBuffer)

        do {
            if let pose = try poseService.detectPose(in: pixelBuffer, orientation: orientation) {
                let count = pose.joints.count
                let averageConfidence: Float
                if count == 0 {
                    averageConfidence = 0
                } else {
                    let total = pose.joints.values.reduce(Float(0)) { $0 + $1.confidence }
                    averageConfidence = total / Float(count)
                }
                logger.info("BodyPose joints=\(count) avgConfidence=\(averageConfidence, format: .fixed(precision: 2))")
                await onPoseUpdate(pose, imageSize)
            } else {
                logger.info("BodyPose nil (no observation)")
                await onPoseUpdate(nil, imageSize)
            }
        } catch {
            logger.error("Pose detection failed: \(error.localizedDescription, privacy: .public)")
            await onPoseUpdate(nil, imageSize)
        }
    }
}
