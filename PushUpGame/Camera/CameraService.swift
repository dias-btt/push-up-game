//
//  CameraService.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import CoreVideo

/// Camera capture as a live frame stream for real-time analysis.
/// Marked `nonisolated` so it is not inferred as `@MainActor` under
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — session start/stop and
/// sample-buffer delivery must not be confined to the main actor.
nonisolated protocol CameraService: Sendable {
    var frames: AsyncStream<CVPixelBuffer> { get }
    var session: AVCaptureSession { get }
    var cameraPosition: AVCaptureDevice.Position { get }
    func start() async throws
    func stop() async
    func switchCamera() async throws
}

enum CameraServiceError: Error, LocalizedError, Sendable {
    case permissionDenied
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access was denied. Enable the camera for PushUpGame in Settings to count push-ups."
        case .cameraUnavailable:
            return "The requested camera is not available on this device."
        case .cannotAddInput:
            return "Could not add the selected camera as a capture session input."
        case .cannotAddOutput:
            return "Could not add video data output to the capture session."
        }
    }
}
