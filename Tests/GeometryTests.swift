//
//  GeometryTests.swift
//  PushUpGameTests
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreGraphics
import XCTest

@testable import PushUpGame

final class GeometryTests: XCTestCase {
    private let tolerance = 0.0001

    func testStraightLineThroughVertexIsOneEightyDegrees() {
        let vertex = CGPoint(x: 0, y: 0)
        let pointA = CGPoint(x: -2, y: 0)
        let pointB = CGPoint(x: 3, y: 0)

        let measured = angle(at: vertex, between: pointA, and: pointB)
        XCTAssertEqual(measured, 180, accuracy: tolerance)
    }

    func testRightAngleAtOrigin() {
        let vertex = CGPoint(x: 0, y: 0)
        let pointA = CGPoint(x: 1, y: 0)
        let pointB = CGPoint(x: 0, y: 1)

        let measured = angle(at: vertex, between: pointA, and: pointB)
        XCTAssertEqual(measured, 90, accuracy: tolerance)
    }

    func testElbowLikeRightAngle() {
        // Shoulder above elbow, wrist to the right — 90° at elbow.
        let shoulder = CGPoint(x: 0.4, y: 0.7)
        let elbow = CGPoint(x: 0.4, y: 0.5)
        let wrist = CGPoint(x: 0.6, y: 0.5)

        let measured = angle(at: elbow, between: shoulder, and: wrist)
        XCTAssertEqual(measured, 90, accuracy: tolerance)
    }

    func testElbowLikeAcuteAngle() {
        // 45° between (1, 0) and (1, 1) at the origin.
        let vertex = CGPoint(x: 0, y: 0)
        let pointA = CGPoint(x: 1, y: 0)
        let pointB = CGPoint(x: 1, y: 1)

        let measured = angle(at: vertex, between: pointA, and: pointB)
        XCTAssertEqual(measured, 45, accuracy: tolerance)
    }

    func testShoulderElbowWristObtuseAngle() {
        // 135° at elbow: upper arm to the right, forearm up-left.
        let elbow = CGPoint(x: 0.4, y: 0.5)
        let shoulder = CGPoint(x: 1.4, y: 0.5)
        let wrist = CGPoint(
            x: elbow.x - CGFloat(2).squareRoot() / 2,
            y: elbow.y + CGFloat(2).squareRoot() / 2
        )

        let measured = angle(at: elbow, between: shoulder, and: wrist)
        XCTAssertEqual(measured, 135, accuracy: tolerance)
    }

    func testVertexCoincidentWithPointAReturnsZero() {
        let vertex = CGPoint(x: 1, y: 2)
        let pointB = CGPoint(x: 4, y: 6)

        let measured = angle(at: vertex, between: vertex, and: pointB)
        XCTAssertEqual(measured, 0, accuracy: tolerance)
    }

    func testVertexCoincidentWithPointBReturnsZero() {
        let vertex = CGPoint(x: 1, y: 2)
        let pointA = CGPoint(x: -1, y: 2)

        let measured = angle(at: vertex, between: pointA, and: vertex)
        XCTAssertEqual(measured, 0, accuracy: tolerance)
    }

    func testAllThreePointsCoincidentReturnsZero() {
        let point = CGPoint(x: 3, y: 3)
        let measured = angle(at: point, between: point, and: point)
        XCTAssertEqual(measured, 0, accuracy: tolerance)
    }
}
