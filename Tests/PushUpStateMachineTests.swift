//
//  PushUpStateMachineTests.swift
//  PushUpGameTests
//
//  Created by Диас Сайынов on 17.09.2026.
//

import XCTest

@testable import PushUpGame

final class PushUpStateMachineTests: XCTestCase {
    private let fps = 10.0
    private let upAngle = 160.0
    private let downAngle = 85.0
    private let descendingAngle = 100.0
    private let ascendingAngle = 148.0

    func testOneFullSlowValidRep() {
        var machine = PushUpStateMachine()
        let events = simulate(
            on: &machine,
            frames: [
                Frame(time: 0.0, angle: upAngle, valid: true),
                Frame(time: 0.5, angle: descendingAngle, valid: true),
                Frame(time: 0.6, angle: downAngle, valid: true),
                Frame(time: 0.7, angle: downAngle, valid: true),
                Frame(time: 0.8, angle: ascendingAngle, valid: true),
                Frame(time: 1.1, angle: upAngle, valid: true),
                Frame(time: 1.2, angle: upAngle, valid: true),
            ]
        )

        XCTAssertEqual(machine.repCount, 1)
        XCTAssertEqual(events.filter { $0 == .repCompleted }.count, 1)
        XCTAssertEqual(machine.state, .up)
    }

    func testOneFullFastValidRepNearMinimumDuration() {
        var machine = PushUpStateMachine()
        let events = simulate(
            on: &machine,
            frames: [
                Frame(time: 0.0, angle: upAngle, valid: true),
                Frame(time: 0.1, angle: descendingAngle, valid: true),
                Frame(time: 0.2, angle: downAngle, valid: true),
                Frame(time: 0.3, angle: downAngle, valid: true),
                Frame(time: 0.4, angle: ascendingAngle, valid: true),
                Frame(time: 0.6, angle: upAngle, valid: true),
                Frame(time: 0.7, angle: upAngle, valid: true),
            ]
        )

        XCTAssertEqual(machine.repCount, 1)
        XCTAssertEqual(events.filter { $0 == .repCompleted }.count, 1)
    }

    func testPartialRepBounceBeforeDownDoesNotCount() {
        var machine = PushUpStateMachine()
        let events = simulate(
            on: &machine,
            frames: [
                Frame(time: 0.0, angle: upAngle, valid: true),
                Frame(time: 0.1, angle: descendingAngle, valid: true),
                Frame(time: 0.2, angle: upAngle, valid: true),
            ]
        )

        XCTAssertEqual(machine.repCount, 0)
        XCTAssertFalse(events.contains(.repCompleted))
        XCTAssertEqual(machine.state, .up)
    }

    func testTooFastFullCycleDoesNotCount() {
        var machine = PushUpStateMachine()
        let events = simulate(
            on: &machine,
            frames: [
                Frame(time: 0.0, angle: upAngle, valid: true),
                Frame(time: 0.01, angle: descendingAngle, valid: true),
                Frame(time: 0.05, angle: downAngle, valid: true),
                Frame(time: 0.1, angle: downAngle, valid: true),
                Frame(time: 0.15, angle: ascendingAngle, valid: true),
                Frame(time: 0.2, angle: upAngle, valid: true),
                Frame(time: 0.25, angle: upAngle, valid: true),
            ]
        )

        XCTAssertEqual(machine.repCount, 0)
        XCTAssertFalse(events.contains(.repCompleted))
        XCTAssertEqual(events.last, .stateChanged(to: .up))
    }

    func testPoseLostThenRecoveredMidRep() {
        var machine = PushUpStateMachine()
        let events = simulate(
            on: &machine,
            frames: [
                Frame(time: 0.0, angle: upAngle, valid: true),
                Frame(time: 0.1, angle: descendingAngle, valid: true),
                Frame(time: 0.2, angle: nil, valid: false),
                Frame(time: 0.8, angle: nil, valid: false),
                Frame(time: 0.9, angle: upAngle, valid: true),
            ]
        )

        XCTAssertEqual(machine.repCount, 0)
        XCTAssertEqual(machine.state, .ready)
        XCTAssertTrue(events.contains(.positionInvalid(reason: "Pose tracking unavailable")))
    }

    func testTwoConsecutiveValidRepsCountsExactlyTwo() {
        var machine = PushUpStateMachine()
        let events = simulate(
            on: &machine,
            frames: [
                // Rep 1
                Frame(time: 0.0, angle: upAngle, valid: true),
                Frame(time: 0.1, angle: descendingAngle, valid: true),
                Frame(time: 0.2, angle: downAngle, valid: true),
                Frame(time: 0.3, angle: downAngle, valid: true),
                Frame(time: 0.4, angle: ascendingAngle, valid: true),
                Frame(time: 0.7, angle: upAngle, valid: true),
                Frame(time: 0.8, angle: upAngle, valid: true),
                // Rep 2
                Frame(time: 0.9, angle: descendingAngle, valid: true),
                Frame(time: 1.0, angle: downAngle, valid: true),
                Frame(time: 1.1, angle: downAngle, valid: true),
                Frame(time: 1.2, angle: ascendingAngle, valid: true),
                Frame(time: 1.5, angle: upAngle, valid: true),
                Frame(time: 1.6, angle: upAngle, valid: true),
            ]
        )

        XCTAssertEqual(machine.repCount, 2)
        XCTAssertEqual(events.filter { $0 == .repCompleted }.count, 2)
    }

    // MARK: - Helpers

    private struct Frame {
        let time: TimeInterval
        let angle: Double?
        let valid: Bool
    }

    private func simulate(
        on machine: inout PushUpStateMachine,
        frames: [Frame]
    ) -> [PushUpEvent] {
        var events: [PushUpEvent] = []
        let start = Date(timeIntervalSinceReferenceDate: 0)

        for frame in frames {
            let now = start.addingTimeInterval(frame.time)
            if let event = machine.update(
                elbowAngle: frame.angle,
                poseValid: frame.valid,
                now: now,
                framesPerSecond: fps
            ) {
                events.append(event)
            }
        }

        return events
    }
}
