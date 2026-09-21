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

    private let session: PushUpSession
    private var consumeTask: Task<Void, Never>?

    init(session: PushUpSession) {
        self.session = session
    }

    func captureSession() async -> AVCaptureSession {
        await session.captureSession()
    }

    func startSession() async {
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
            print("Session start failed: \(error.localizedDescription)")
        }
    }

    func stopSession() async {
        consumeTask?.cancel()
        consumeTask = nil
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

    private func apply(_ update: SessionUpdate) {
        latestPose = update.pose
        latestAnalyzedFrame = update.analyzedFrame
        currentState = update.state
        repCount = update.repCount
        orientedImageSize = update.orientedImageSize
    }
}
