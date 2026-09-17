//
//  PushUpAnalyzerTests.swift
//  PushUpGameTests
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreGraphics
import XCTest

@testable import PushUpGame

final class PushUpAnalyzerTests: XCTestCase {
    private let angleTolerance = 0.0001
    private let smoothingTolerance = 0.0001

    func testBothSidesConfidentlyVisible() {
        var analyzer = PushUpAnalyzer()
        let pose = makeSymmetricPose(leftConfidence: 0.9, rightConfidence: 0.9)

        let frame = analyzer.process(pose, at: Date())

        XCTAssertTrue(frame.poseValid)
        XCTAssertNotNil(frame.leftElbowAngle)
        XCTAssertNotNil(frame.rightElbowAngle)
        XCTAssertNotNil(frame.bodyLineAngle)
        XCTAssertEqual(frame.leftElbowAngle ?? -1, 90, accuracy: angleTolerance)
        XCTAssertEqual(frame.rightElbowAngle ?? -1, 90, accuracy: angleTolerance)
        XCTAssertNotNil(frame.trustedSide)
    }

    func testOnlyLeftVisible() {
        var analyzer = PushUpAnalyzer()
        let pose = makeSymmetricPose(leftConfidence: 0.9, rightConfidence: 0.2)

        let frame = analyzer.process(pose, at: Date())

        XCTAssertTrue(frame.poseValid)
        XCTAssertNotNil(frame.leftElbowAngle)
        XCTAssertNil(frame.rightElbowAngle)
        XCTAssertEqual(frame.trustedSide, .left)
    }

    func testOnlyRightVisible() {
        var analyzer = PushUpAnalyzer()
        let pose = makeSymmetricPose(leftConfidence: 0.2, rightConfidence: 0.9)

        let frame = analyzer.process(pose, at: Date())

        XCTAssertTrue(frame.poseValid)
        XCTAssertNil(frame.leftElbowAngle)
        XCTAssertNotNil(frame.rightElbowAngle)
        XCTAssertEqual(frame.trustedSide, .right)
    }

    func testNeitherSideVisible() {
        var analyzer = PushUpAnalyzer()
        let pose = makeSymmetricPose(leftConfidence: 0.2, rightConfidence: 0.2)

        let frame = analyzer.process(pose, at: Date())

        XCTAssertFalse(frame.poseValid)
        XCTAssertNil(frame.leftElbowAngle)
        XCTAssertNil(frame.rightElbowAngle)
        XCTAssertNil(frame.trustedSide)
        XCTAssertNil(frame.smoothedTrustedElbowAngle)
    }

    func testTrustedSideDoesNotFlickerOnSingleFrameBlip() {
        var analyzer = PushUpAnalyzer()
        let leftOnlyPose = makeSymmetricPose(leftConfidence: 0.95, rightConfidence: 0.2)
        let rightBlipPose = makeSymmetricPose(leftConfidence: 0.85, rightConfidence: 0.99)
        let rightFavoredPose = makeSymmetricPose(leftConfidence: 0.7, rightConfidence: 0.95)

        for _ in 0..<6 {
            let frame = analyzer.process(leftOnlyPose, at: Date())
            XCTAssertEqual(frame.trustedSide, .left)
        }

        let blipFrame = analyzer.process(rightBlipPose, at: Date())
        XCTAssertEqual(blipFrame.trustedSide, .left)

        for _ in 0..<(PushUpThresholds.trustedSideSwitchFrameCount - 2) {
            let frame = analyzer.process(rightFavoredPose, at: Date())
            XCTAssertEqual(frame.trustedSide, .left)
        }

        let switchedFrame = analyzer.process(rightFavoredPose, at: Date())
        XCTAssertEqual(switchedFrame.trustedSide, .right)
    }

    func testElbowSmoothingDoesNotJumpInstantly() {
        var analyzer = PushUpAnalyzer()
        let stablePose = makeLeftElbowPose(angleDegrees: 90, confidence: 0.95)
        let spikePose = makeLeftElbowPose(angleDegrees: 170, confidence: 0.95)

        for _ in 0..<8 {
            _ = analyzer.process(stablePose, at: Date())
        }

        let stabilized = analyzer.process(stablePose, at: Date())
        XCTAssertEqual(stabilized.smoothedTrustedElbowAngle ?? -1, 90, accuracy: smoothingTolerance)

        let afterSpike = analyzer.process(spikePose, at: Date())
        XCTAssertEqual(afterSpike.leftElbowAngle ?? -1, 170, accuracy: angleTolerance)
        XCTAssertEqual(afterSpike.smoothedTrustedElbowAngle ?? -1, 122, accuracy: smoothingTolerance)
        XCTAssertNotEqual(afterSpike.smoothedTrustedElbowAngle, afterSpike.leftElbowAngle)
    }

    // MARK: - Fixtures

    private func makeSymmetricPose(leftConfidence: Float, rightConfidence: Float) -> BodyPose {
        let leftElbow = CGPoint(x: 0.3, y: 0.5)
        let rightElbow = CGPoint(x: 0.7, y: 0.5)
        let joints: [BodyJoint: BodyPose.JointPoint] = [
            .leftShoulder: point(leftElbow, dx: 0, dy: 0.2, confidence: leftConfidence),
            .leftElbow: point(leftElbow, confidence: leftConfidence),
            .leftWrist: point(leftElbow, dx: 0.2, dy: 0, confidence: leftConfidence),
            .leftHip: point(leftElbow, dx: 0, dy: -0.2, confidence: leftConfidence),
            .leftAnkle: point(leftElbow, dx: 0.2, dy: -0.4, confidence: leftConfidence),
            .rightShoulder: point(rightElbow, dx: 0, dy: 0.2, confidence: rightConfidence),
            .rightElbow: point(rightElbow, confidence: rightConfidence),
            .rightWrist: point(rightElbow, dx: -0.2, dy: 0, confidence: rightConfidence),
            .rightHip: point(rightElbow, dx: 0, dy: -0.2, confidence: rightConfidence),
            .rightAnkle: point(rightElbow, dx: -0.2, dy: -0.4, confidence: rightConfidence),
        ]
        return BodyPose(joints: joints)
    }

    private func makeLeftElbowPose(angleDegrees: Double, confidence: Float) -> BodyPose {
        let elbow = CGPoint(x: 0.3, y: 0.5)
        let shoulder = CGPoint(x: elbow.x + 1, y: elbow.y)
        let radians = angleDegrees * .pi / 180
        let wrist = CGPoint(
            x: elbow.x + CGFloat(cos(radians)),
            y: elbow.y + CGFloat(sin(radians))
        )

        let joints: [BodyJoint: BodyPose.JointPoint] = [
            .leftShoulder: BodyPose.JointPoint(location: shoulder, confidence: confidence),
            .leftElbow: BodyPose.JointPoint(location: elbow, confidence: confidence),
            .leftWrist: BodyPose.JointPoint(location: wrist, confidence: confidence),
            .leftHip: BodyPose.JointPoint(location: CGPoint(x: 0.3, y: 0.3), confidence: confidence),
            .leftAnkle: BodyPose.JointPoint(location: CGPoint(x: 0.5, y: 0.1), confidence: confidence),
            .rightShoulder: BodyPose.JointPoint(location: CGPoint(x: 0.7, y: 0.7), confidence: 0.2),
            .rightElbow: BodyPose.JointPoint(location: CGPoint(x: 0.7, y: 0.5), confidence: 0.2),
            .rightWrist: BodyPose.JointPoint(location: CGPoint(x: 0.9, y: 0.5), confidence: 0.2),
        ]
        return BodyPose(joints: joints)
    }

    private func point(
        _ origin: CGPoint,
        dx: CGFloat = 0,
        dy: CGFloat = 0,
        confidence: Float
    ) -> BodyPose.JointPoint {
        BodyPose.JointPoint(
            location: CGPoint(x: origin.x + dx, y: origin.y + dy),
            confidence: confidence
        )
    }
}
