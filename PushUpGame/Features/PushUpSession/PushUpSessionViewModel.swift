//
//  PushUpSessionViewModel.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class PushUpSessionViewModel {
    private(set) var repCount: Int = 0
    private(set) var currentState: PushUpState = .unknown
    private(set) var latestPose: BodyPose?
    private(set) var latestAnalyzedFrame: AnalyzedFrame?
    private(set) var orientedImageSize = CGSize(width: 9, height: 16)
    private(set) var cameraPosition: AVCaptureDevice.Position = .back
    private(set) var positioningStatus: PositioningStatus = .noPersonDetected
    private(set) var isWorkoutActive = false

    private(set) var analysisFPS: Double = 0
    private(set) var framesInCurrentState: Int = 0
    private(set) var lastRepDuration: TimeInterval?

    #if DEBUG
    var isCSVLoggingEnabled = DebugSessionLogger.isEnabled
    #endif

    private let session: PushUpSession
    private var consumeTask: Task<Void, Never>?
    private var lastUpdateTimestamp: Date?
    private var fpsIntervals: [TimeInterval] = []

    init(session: PushUpSession) {
        self.session = session
    }

    func captureSession() async -> AVCaptureSession {
        await session.captureSession()
    }

    /// Starts camera + pose detection for positioning feedback (no rep counting yet).
    func startPositioning() async {
        do {
            try await session.start()
            cameraPosition = await session.cameraPosition()

            consumeTask?.cancel()
            let updates = await session.updates
            consumeTask = Task { @MainActor in
                for await update in updates {
                    apply(update)
                }
            }
        } catch {
            print("Positioning start failed: \(error.localizedDescription)")
        }
    }

    func beginWorkout() async {
        await session.beginWorkout()
        isWorkoutActive = true
        repCount = 0
        currentState = .unknown
        latestAnalyzedFrame = nil
        framesInCurrentState = 0
        lastRepDuration = nil
    }

    func stopSession() async {
        consumeTask?.cancel()
        consumeTask = nil
        isWorkoutActive = false
        await session.stop()
    }

    func switchCamera() async {
        do {
            try await session.switchCamera()
            cameraPosition = await session.cameraPosition()
            latestPose = nil
        } catch {
            print("Camera switch failed: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    func setCSVLoggingEnabled(_ enabled: Bool) {
        isCSVLoggingEnabled = enabled
        DebugSessionLogger.isEnabled = enabled
    }
    #endif

    private func apply(_ update: SessionUpdate) {
        latestPose = update.pose
        latestAnalyzedFrame = update.analyzedFrame
        orientedImageSize = update.orientedImageSize
        positioningStatus = update.positioningStatus
        updateMeasuredFPS(at: update.timestamp)

        framesInCurrentState = update.framesInCurrentState
        if let duration = update.lastRepDuration {
            lastRepDuration = duration
        }

        if isWorkoutActive {
            currentState = update.state
            repCount = update.repCount
        }
    }

    private func updateMeasuredFPS(at timestamp: Date) {
        if let lastUpdateTimestamp {
            let interval = timestamp.timeIntervalSince(lastUpdateTimestamp)
            if interval > 0 {
                fpsIntervals.append(interval)
                if fpsIntervals.count > 20 {
                    fpsIntervals.removeFirst(fpsIntervals.count - 20)
                }
                let averageInterval = fpsIntervals.reduce(0, +) / Double(fpsIntervals.count)
                analysisFPS = 1.0 / averageInterval
            }
        }
        lastUpdateTimestamp = timestamp
    }
}
