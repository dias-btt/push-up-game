//
//  CameraPreviewView.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let cameraPosition: AVCaptureDevice.Position

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.updateMirroring(for: cameraPosition)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.previewLayer.videoGravity = .resizeAspectFill
        uiView.updateMirroring(for: cameraPosition)
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            backgroundColor = .black
        }

        func updateMirroring(for cameraPosition: AVCaptureDevice.Position) {
            guard let connection = previewLayer.connection else { return }
            guard connection.isVideoMirroringSupported else { return }
            // Manual mirroring is required for front-camera preview; AVFoundation throws if
            // `automaticallyAdjustsVideoMirroring` is still enabled.
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = cameraPosition == .front
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            updateVideoRotation()
        }

        private func updateVideoRotation() {
            guard let connection = previewLayer.connection else { return }
            let angle = videoRotationAngleForCurrentOrientation
            guard connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }

        private var videoRotationAngleForCurrentOrientation: CGFloat {
            switch window?.windowScene?.interfaceOrientation {
            case .portrait:
                return 90
            case .portraitUpsideDown:
                return 270
            case .landscapeRight:
                return 180
            case .landscapeLeft:
                return 0
            default:
                return 90
            }
        }
    }
}
