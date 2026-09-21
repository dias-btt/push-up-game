//
//  PushUpSession.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import CoreVideo
import Foundation
import UIKit

struct SessionUpdate: Sendable {
    let pose: BodyPose?
    let analyzedFrame: AnalyzedFrame
    let state: PushUpState
    let repCount: Int
    let event: PushUpEvent?
    let orientedImageSize: CGSize
}

actor PushUpSession {
    private let cameraService: CameraService
    private let poseDetectionService: PoseDetectionService

    private var analyzer = PushUpAnalyzer()
    private var stateMachine = PushUpStateMachine()
    private var processingTask: Task<Void, Never>?
    private var updateContinuation: AsyncStream<SessionUpdate>.Continuation?

    private(set) var updates: AsyncStream<SessionUpdate>

    init(cameraService: CameraService, poseDetectionService: PoseDetectionService) {
        self.cameraService = cameraService
        self.poseDetectionService = poseDetectionService

        var continuation: AsyncStream<SessionUpdate>.Continuation?
        updates = AsyncStream { continuation = $0 }
        updateContinuation = continuation
    }

    func captureSession() -> AVCaptureSession {
        cameraService.session
    }

    func cameraPosition() -> AVCaptureDevice.Position {
        cameraService.cameraPosition
    }

    func switchCamera() async throws {
        try await cameraService.switchCamera()
    }

    func start() async throws {
        try await cameraService.start()

        guard processingTask == nil else { return }

        processingTask = Task {
            await runProcessingLoop()
        }
    }

    func stop() async {
        processingTask?.cancel()
        processingTask = nil
        await cameraService.stop()
    }

    private func runProcessingLoop() async {
        await MainActor.run {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }

        let minFrameInterval = 1.0 / PushUpThresholds.targetAnalyzedFramesPerSecond
        var lastProcessedTime: Date?

        for await pixelBuffer in cameraService.frames {
            if Task.isCancelled { break }

            let now = Date()
            if let lastProcessedTime, now.timeIntervalSince(lastProcessedTime) < minFrameInterval {
                continue
            }
            lastProcessedTime = now

            let update = await buildSessionUpdate(from: pixelBuffer, at: now)
            updateContinuation?.yield(update)
        }

        await MainActor.run {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    private struct PoseFrameInputs: Sendable {
        let pose: BodyPose?
        let orientedImageSize: CGSize
    }

    private func buildSessionUpdate(from pixelBuffer: CVPixelBuffer, at now: Date) async -> SessionUpdate {
        let inputs = await capturePoseFrameInputs(from: pixelBuffer)
        return await applyAnalysis(inputs: inputs, at: now)
    }

    private func capturePoseFrameInputs(from pixelBuffer: CVPixelBuffer) async -> PoseFrameInputs {
        let cameraPosition = cameraService.cameraPosition
        let orientation = await MainActor.run {
            CGImagePropertyOrientation(
                deviceOrientation: UIDevice.current.orientation,
                cameraPosition: cameraPosition
            )
        }
        let orientedImageSize = orientation.orientedImageSize(for: pixelBuffer)

        let pose: BodyPose?
        do {
            pose = try poseDetectionService.detectPose(in: pixelBuffer, orientation: orientation)
        } catch {
            pose = nil
        }

        return PoseFrameInputs(pose: pose, orientedImageSize: orientedImageSize)
    }

    private func applyAnalysis(inputs: PoseFrameInputs, at now: Date) -> SessionUpdate {
        let analyzedFrame = analyzer.process(inputs.pose ?? BodyPose(joints: [:]), at: now)

        let event = stateMachine.update(
            elbowAngle: analyzedFrame.smoothedTrustedElbowAngle,
            poseValid: analyzedFrame.poseValid,
            now: now,
            framesPerSecond: PushUpThresholds.targetAnalyzedFramesPerSecond
        )

        return SessionUpdate(
            pose: inputs.pose,
            analyzedFrame: analyzedFrame,
            state: stateMachine.state,
            repCount: stateMachine.repCount,
            event: event,
            orientedImageSize: inputs.orientedImageSize
        )
    }
}
