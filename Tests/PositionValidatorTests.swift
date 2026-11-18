//
//  PositionValidatorTests.swift
//  PushUpGameTests
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreGraphics
import XCTest

@testable import PushUpGame

final class PositionValidatorTests: XCTestCase {
    func testNilPoseIsNoPersonDetected() {
        var validator = PositionValidator()
        XCTAssertEqual(validator.evaluate(nil), .noPersonDetected)
    }

    func testMissingRequiredJointsIsNoPersonDetected() {
        var validator = PositionValidator()
        let pose = BodyPose(joints: [
            .leftShoulder: joint(0.4, 0.7, confidence: 0.9),
            .rightShoulder: joint(0.6, 0.7, confidence: 0.9),
        ])

        XCTAssertEqual(validator.evaluate(pose), .noPersonDetected)
    }

    func testSmallBoundingBoxIsTooFar() {
        var validator = PositionValidator()
        let pose = makeCenteredPose(scale: 0.12)

        XCTAssertEqual(validator.evaluate(pose), .tooFar)
    }

    func testLargeBoundingBoxIsTooClose() {
        var validator = PositionValidator()
        let pose = BodyPose(joints: [
            .leftShoulder: joint(0.08, 0.92, confidence: 0.95),
            .rightShoulder: joint(0.92, 0.92, confidence: 0.95),
            .leftHip: joint(0.12, 0.58, confidence: 0.95),
            .rightHip: joint(0.88, 0.58, confidence: 0.95),
            .leftKnee: joint(0.14, 0.34, confidence: 0.95),
            .rightKnee: joint(0.86, 0.34, confidence: 0.95),
            .leftAnkle: joint(0.16, 0.10, confidence: 0.95),
            .rightAnkle: joint(0.84, 0.10, confidence: 0.95),
        ])

        XCTAssertEqual(validator.evaluate(pose), .tooClose)
    }

    func testJointNearEdgeIsPartiallyOutOfFrame() {
        var validator = PositionValidator()
        let pose = makeCenteredPose(scale: 0.35, centerY: 0.03)

        XCTAssertEqual(validator.evaluate(pose), .partiallyOutOfFrame)
    }

    func testGoodPoseRequiresDebounceBeforeReady() {
        var validator = PositionValidator()
        let pose = makeCenteredPose(scale: 0.55)

        XCTAssertEqual(validator.evaluate(pose), .checking)
        for _ in 0..<(PushUpThresholds.positioningReadyFrameCount - 2) {
            XCTAssertEqual(validator.evaluate(pose), .checking)
        }
        XCTAssertEqual(validator.evaluate(pose), .ready)
    }

    func testReadyDebounceResetsAfterBadPose() {
        var validator = PositionValidator()
        let goodPose = makeCenteredPose(scale: 0.55)
        let badPose = makeCenteredPose(scale: 0.12)

        for _ in 0..<3 {
            XCTAssertEqual(validator.evaluate(goodPose), .checking)
        }
        XCTAssertEqual(validator.evaluate(badPose), .tooFar)
        XCTAssertEqual(validator.evaluate(goodPose), .checking)
    }

    // MARK: - Fixtures

    private func makeCenteredPose(scale: CGFloat, centerY: CGFloat = 0.5) -> BodyPose {
        let centerX: CGFloat = 0.5
        let halfWidth = scale * 0.22
        let halfHeight = scale * 0.35

        return BodyPose(joints: [
            .leftShoulder: joint(centerX - halfWidth, centerY + halfHeight, confidence: 0.95),
            .rightShoulder: joint(centerX + halfWidth, centerY + halfHeight, confidence: 0.95),
            .leftHip: joint(centerX - halfWidth * 0.7, centerY, confidence: 0.95),
            .rightHip: joint(centerX + halfWidth * 0.7, centerY, confidence: 0.95),
            .leftKnee: joint(centerX - halfWidth * 0.6, centerY - halfHeight * 0.5, confidence: 0.95),
            .rightKnee: joint(centerX + halfWidth * 0.6, centerY - halfHeight * 0.5, confidence: 0.95),
            .leftAnkle: joint(centerX - halfWidth * 0.5, centerY - halfHeight, confidence: 0.95),
            .rightAnkle: joint(centerX + halfWidth * 0.5, centerY - halfHeight, confidence: 0.95),
        ])
    }

    private func joint(_ x: CGFloat, _ y: CGFloat, confidence: Float) -> BodyPose.JointPoint {
        BodyPose.JointPoint(location: CGPoint(x: x, y: y), confidence: confidence)
    }
}
