//
//  CaptureImageOrientation.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import AVFoundation
import CoreVideo
import ImageIO
import UIKit

extension CGImagePropertyOrientation {
    /// EXIF orientation for *unrotated* `AVCaptureVideoDataOutput` buffers.
    ///
    /// The camera sensor is landscape-native. Portrait frames are therefore not
    /// `.up`. Front-camera buffers use the mirrored variants because that sensor
    /// is mounted on the opposite face of the device.
    ///
    /// Face-up / face-down / unknown fall back to the portrait mapping — never
    /// to `.up`, which would tell Vision the buffer is already upright.
    init(deviceOrientation: UIDeviceOrientation, cameraPosition: AVCaptureDevice.Position) {
        let isFront = cameraPosition == .front
        switch deviceOrientation {
        case .portrait:
            self = isFront ? .leftMirrored : .right
        case .portraitUpsideDown:
            self = isFront ? .rightMirrored : .left
        case .landscapeLeft:
            self = isFront ? .downMirrored : .up
        case .landscapeRight:
            self = isFront ? .upMirrored : .down
        default:
            self = isFront ? .leftMirrored : .right
        }
    }

    /// Pixel dimensions of the image Vision uses after applying this orientation.
    func orientedImageSize(for pixelBuffer: CVPixelBuffer) -> CGSize {
        let bufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let bufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        switch self {
        case .up, .down, .upMirrored, .downMirrored:
            return CGSize(width: bufferWidth, height: bufferHeight)
        case .left, .right, .leftMirrored, .rightMirrored:
            return CGSize(width: bufferHeight, height: bufferWidth)
        default:
            return CGSize(width: bufferWidth, height: bufferHeight)
        }
    }
}
