//
//  AlarmConfigurationTests.swift
//  PushUpGameTests
//

import XCTest

@testable import PushUpGame

final class AlarmConfigurationTests: XCTestCase {
    func testDefaults() {
        let configuration = AlarmConfiguration()

        XCTAssertEqual(configuration.pushUpTarget, 10)
        XCTAssertEqual(configuration.time, .wakeUpDefault)
        XCTAssertTrue(configuration.isOneTime)
        XCTAssertTrue(configuration.isEnabled)
        XCTAssertNil(configuration.validationError)
    }

    func testPushUpTargetBoundsAreAccepted() {
        for target in [AlarmConfiguration.pushUpTargetRange.lowerBound, AlarmConfiguration.pushUpTargetRange.upperBound] {
            XCTAssertNoThrow(try AlarmConfiguration(pushUpTarget: target).validated())
        }
    }

    func testPushUpTargetOutOfRangeIsRejected() {
        for target in [0, -3, AlarmConfiguration.pushUpTargetRange.upperBound + 1] {
            XCTAssertThrowsError(try AlarmConfiguration(pushUpTarget: target).validated()) { error in
                XCTAssertEqual(error as? AlarmValidationError, .pushUpTargetOutOfRange(target))
            }
        }
    }

    func testTitleIsTrimmed() throws {
        let validated = try AlarmConfiguration(title: "  Morning \n").validated()
        XCTAssertEqual(validated.title, "Morning")
    }

    func testTitleLengthLimitAppliesAfterTrimming() throws {
        let maxLength = AlarmConfiguration.maximumTitleLength
        let atLimit = String(repeating: "a", count: maxLength)

        XCTAssertNoThrow(try AlarmConfiguration(title: "  \(atLimit)  ").validated())
        XCTAssertEqual(
            AlarmConfiguration(title: atLimit + "b").validationError,
            .titleTooLong(maximumLength: maxLength)
        )
    }

    func testEmptyTitleFallsBackForDisplay() {
        XCTAssertEqual(AlarmConfiguration(title: "   ").displayTitle, AlarmConfiguration.fallbackTitle)
        XCTAssertEqual(AlarmConfiguration(title: " Gym ").displayTitle, "Gym")
    }

    func testInvalidRepeatMaskIsRejected() {
        let configuration = AlarmConfiguration(repeatDays: WeekdaySet(rawValue: 0b1000_0000))
        XCTAssertEqual(configuration.validationError, .invalidRepeatDays(rawValue: 0b1000_0000))
    }
}
