//
//  AVFoundationCameraService.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import CoreVideo
import Foundation

/// Live camera frames via `AVCaptureSession` + `AVCaptureVideoDataOutput`.
///
/// Implemented as a class confined to serial dispatch queues rather than an
/// actor. `AVCaptureVideoDataOutputSampleBufferDelegate` is an `@objc`
/// protocol with a *synchronous* callback; actors cannot inherit `NSObject`,
/// and hopping into actor isolation from that callback (`Task { await … }`)
/// would delay buffer release and can race with `bufferingNewest(1)`.
/// Session mutation is serialized on `sessionQueue`; frames are published on
/// `sampleBufferQueue` through a thread-safe `AsyncStream.Continuation`.
nonisolated final class AVFoundationCameraService: NSObject, CameraService, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let frames: AsyncStream<CVPixelBuffer>

    private let continuation: AsyncStream<CVPixelBuffer>.Continuation
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.pushupgame.camera.session")
    private let sampleBufferQueue = DispatchQueue(label: "com.pushupgame.camera.frames")

    private var isConfigured = false
    /// Session-queue flag so a stop that lands before `startRunning` finishes
    /// cannot leave the capture session running after the UI has gone away.
    private var wantsRunning = false

    var session: AVCaptureSession { captureSession }
    let cameraPosition: AVCaptureDevice.Position = .back

    override init() {
        var streamContinuation: AsyncStream<CVPixelBuffer>.Continuation!
        frames = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            streamContinuation = continuation
        }
        continuation = streamContinuation
        super.init()
    }

    deinit {
        continuation.finish()
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    func start() async throws {
        try await requestCameraAccessIfNeeded()
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    wantsRunning = true
                    if !isConfigured {
                        try configureSession()
                        isConfigured = true
                    }
                    if wantsRunning, !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                    continuation.resume()
                } catch {
                    wantsRunning = false
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                wantsRunning = false
                if captureSession.isRunning {
                    captureSession.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Permission

    private func requestCameraAccessIfNeeded() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                throw CameraServiceError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraServiceError.permissionDenied
        @unknown default:
            throw CameraServiceError.permissionDenied
        }
    }

    // MARK: - Session

    /// Must be called on `sessionQueue`.
    private func configureSession() throws {
        dispatchPrecondition(condition: .onQueue(sessionQueue))

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        } else {
            captureSession.sessionPreset = .medium
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraServiceError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(input) else {
            throw CameraServiceError.cannotAddInput
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw CameraServiceError.cannotAddOutput
        }
        captureSession.addOutput(videoOutput)
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        dispatchPrecondition(condition: .onQueue(sampleBufferQueue))
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        continuation.yield(pixelBuffer)
    }
}
