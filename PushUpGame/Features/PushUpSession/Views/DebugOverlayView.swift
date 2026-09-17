//
//  DebugOverlayView.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import SwiftUI

/// Draws a body skeleton over the camera preview using Vision-normalized joint positions.
struct SkeletonOverlayView: View {
    let pose: BodyPose
    /// Size of the oriented image Vision analyzed (must match the orientation passed to detection).
    let orientedImageSize: CGSize
    let size: CGSize

    private static let boneConnections: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .rightShoulder),
        (.leftHip, .rightHip),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let layout = PoseOverlayLayout(orientedImageSize: orientedImageSize, viewSize: canvasSize)

            for (startJoint, endJoint) in Self.boneConnections {
                guard
                    let start = pose.joints[startJoint],
                    let end = pose.joints[endJoint]
                else { continue }

                let startPoint = layout.viewPoint(fromVisionNormalized: start.location)
                let endPoint = layout.viewPoint(fromVisionNormalized: end.location)

                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
            }

            for joint in BodyJoint.allCases {
                guard let point = pose.joints[joint] else { continue }
                let center = layout.viewPoint(fromVisionNormalized: point.location)
                let radius: CGFloat = 6
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(confidenceColor(point.confidence)))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.5 {
            return .green
        }
        if confidence >= 0.3 {
            return .yellow
        }
        return .red
    }
}

/// Maps Vision normalized coordinates into view space for `.resizeAspectFill` preview.
private struct PoseOverlayLayout {
    let orientedImageSize: CGSize
    let viewSize: CGSize

    private let scale: CGFloat
    private let offset: CGPoint

    init(orientedImageSize: CGSize, viewSize: CGSize) {
        self.orientedImageSize = orientedImageSize
        self.viewSize = viewSize

        let imageWidth = max(orientedImageSize.width, 1)
        let imageHeight = max(orientedImageSize.height, 1)
        scale = max(viewSize.width / imageWidth, viewSize.height / imageHeight)

        let displayedWidth = imageWidth * scale
        let displayedHeight = imageHeight * scale
        offset = CGPoint(
            x: (viewSize.width - displayedWidth) / 2,
            y: (viewSize.height - displayedHeight) / 2
        )
    }

    /// Vision: origin bottom-left, normalized 0–1. View: origin top-left, aspect-fill crop.
    func viewPoint(fromVisionNormalized visionPoint: CGPoint) -> CGPoint {
        let imageX = visionPoint.x * orientedImageSize.width
        let imageY = (1 - visionPoint.y) * orientedImageSize.height
        return CGPoint(
            x: imageX * scale + offset.x,
            y: imageY * scale + offset.y
        )
    }
}
