//
//  PushUpSessionLifecycleTests.swift
//  PushUpGameTests
//

import AVFoundation
import CoreVideo
import ImageIO
import XCTest

@testable import PushUpGame

/// Lifecycle only — uses fakes, never a physical camera or Vision.
final class PushUpSessionLifecycleTests: XCTestCase {
    /// Leaving the workout screen while the camera is still starting must not
    /// leave capture running once that start completes.
    func testStopDuringInFlightStartLeavesCameraStopped() async throws {
        let camera = GatedCameraService()
        let session = PushUpSession(cameraService: camera, poseDetectionService: NoPoseDetectionService())

        let startTask = Task { try await session.start() }
        await camera.waitUntilStartIsPending()

        await session.stop()
        camera.releasePendingStart()
        try await startTask.value

        XCTAssertFalse(camera.isRunning)
    }

    func testNormalStartLeavesCameraRunningUntilStopped() async throws {
        let camera = GatedCameraService(startsImmediately: true)
        let session = PushUpSession(cameraService: camera, poseDetectionService: NoPoseDetectionService())

        try await session.start()
        XCTAssertTrue(camera.isRunning)

        await session.stop()
        XCTAssertFalse(camera.isRunning)
    }
}

// MARK: - Fakes

private struct NoPoseDetectionService: PoseDetectionService {
    func detectPose(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> BodyPose? {
        nil
    }
}

/// Camera fake whose `start()` can be held open to reproduce the reentrancy window.
private final class GatedCameraService: CameraService, @unchecked Sendable {
    let frames: AsyncStream<CVPixelBuffer>
    let session = AVCaptureSession()
    let cameraPosition: AVCaptureDevice.Position = .back

    private let lock = NSLock()
    private let startsImmediately: Bool
    private var running = false
    private var pendingStart: CheckedContinuation<Void, Never>?
    private var pendingStartWaiters: [CheckedContinuation<Void, Never>] = []

    init(startsImmediately: Bool = false) {
        self.startsImmediately = startsImmediately
        frames = AsyncStream { _ in }
    }

    var isRunning: Bool {
        lock.withLock { running }
    }

    func start() async throws {
        if !startsImmediately {
            await withCheckedContinuation { continuation in
                let waiters = lock.withLock {
                    pendingStart = continuation
                    defer { pendingStartWaiters.removeAll() }
                    return pendingStartWaiters
                }
                waiters.forEach { $0.resume() }
            }
        }
        lock.withLock { running = true }
    }

    func stop() async {
        lock.withLock { running = false }
    }

    func switchCamera() async throws {}

    func waitUntilStartIsPending() async {
        await withCheckedContinuation { continuation in
            let alreadyPending = lock.withLock {
                if pendingStart != nil { return true }
                pendingStartWaiters.append(continuation)
                return false
            }
            if alreadyPending { continuation.resume() }
        }
    }

    func releasePendingStart() {
        let continuation = lock.withLock {
            defer { pendingStart = nil }
            return pendingStart
        }
        continuation?.resume()
    }
}
