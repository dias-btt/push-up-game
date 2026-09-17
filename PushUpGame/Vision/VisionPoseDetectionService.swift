//
//  VisionPoseDetectionService.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreVideo
import ImageIO
import Vision

enum PoseDetectionError: Error, LocalizedError, Sendable {
    case unmappedVisionJoint(String)

    var errorDescription: String? {
        switch self {
        case .unmappedVisionJoint(let name):
            return "Unmapped VNHumanBodyPoseObservation.JointName: \(name)"
        }
    }
}

/// Body-pose detection via `VNDetectHumanBodyPoseRequest`.
/// This is the only file in the project that imports Vision.
nonisolated struct VisionPoseDetectionService: PoseDetectionService, Sendable {
    func detectPose(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> BodyPose? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        let recognizedPoints = try observation.recognizedPoints(.all)
        try Self.throwIfUnrecognizedVisionJoints(in: recognizedPoints.keys)

        var joints: [BodyJoint: BodyPose.JointPoint] = [:]
        joints.reserveCapacity(BodyJoint.allCases.count)

        for joint in BodyJoint.allCases {
            let visionName = Self.visionJointName(for: joint)
            guard let point = recognizedPoints[visionName] else { continue }
            joints[joint] = BodyPose.JointPoint(location: point.location, confidence: point.confidence)
        }

        return BodyPose(joints: joints)
    }

    /// Explicit, compiler-exhaustive mapping — adding a `BodyJoint` is a compile error here.
    private static func visionJointName(for joint: BodyJoint) -> VNHumanBodyPoseObservation.JointName {
        switch joint {
        case .nose: return .nose
        case .leftEye: return .leftEye
        case .rightEye: return .rightEye
        case .leftEar: return .leftEar
        case .rightEar: return .rightEar
        case .neck: return .neck
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftElbow: return .leftElbow
        case .rightElbow: return .rightElbow
        case .leftWrist: return .leftWrist
        case .rightWrist: return .rightWrist
        case .root: return .root
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        }
    }

    /// Reverse mapping of every relevant Vision joint. Unknown names throw
    /// rather than being dropped silently.
    private static func bodyJoint(from name: VNHumanBodyPoseObservation.JointName) throws -> BodyJoint {
        switch name {
        case .nose: return .nose
        case .leftEye: return .leftEye
        case .rightEye: return .rightEye
        case .leftEar: return .leftEar
        case .rightEar: return .rightEar
        case .neck: return .neck
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftElbow: return .leftElbow
        case .rightElbow: return .rightElbow
        case .leftWrist: return .leftWrist
        case .rightWrist: return .rightWrist
        case .root: return .root
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        default:
            throw PoseDetectionError.unmappedVisionJoint("\(name.rawValue)")
        }
    }

    private static func throwIfUnrecognizedVisionJoints(
        in names: Dictionary<VNHumanBodyPoseObservation.JointName, VNRecognizedPoint>.Keys
    ) throws {
        for name in names {
            _ = try bodyJoint(from: name)
        }
    }
}
