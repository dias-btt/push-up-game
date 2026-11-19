//
//  AlarmChallengeRouterTests.swift
//  PushUpGameTests
//

import SwiftData
import XCTest

@testable import PushUpGame

/// Routing from the alarm alert's "Start Push-Ups" action to the challenge
/// screen. Uses an isolated UserDefaults suite and in-memory SwiftData store;
/// no real alarms or intents are involved.
@MainActor
final class AlarmChallengeRouterTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var container: ModelContainer!
    private var currentDate = Date(timeIntervalSince1970: 1_800_000_000)

    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        suiteName = "AlarmChallengeRouterTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        container = try AppDependencies.makeModelContainer(inMemory: true)
    }

    override func tearDown() async throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        container = nil
    }

    // MARK: - Routing

    func testExistingAlarmOpensItsChallenge() throws {
        let record = try insert(AlarmConfiguration(title: "Gym", pushUpTarget: 25))
        let router = makeActivatedRouter()

        router.receive(alarmID: record.id)

        XCTAssertEqual(router.path, [.alarmChallenge(record.id)])
        XCTAssertEqual(router.activeChallengeID, record.id)
        XCTAssertFalse(router.isShowingUnavailableAlarmNotice)
        XCTAssertNil(makeStore().load(), "request consumed")
    }

    func testChallengeResolvesTitleAndTargetFromRecord() throws {
        let record = try insert(AlarmConfiguration(title: "Gym", pushUpTarget: 25))

        let challenge = AlarmRecord.challenge(for: record.id, in: context)

        XCTAssertEqual(challenge, AlarmChallenge(alarmID: record.id, title: "Gym", pushUpTarget: 25))
    }

    func testDisabledAlarmStillResolves() throws {
        // A one-time alarm is turned off right after it rings.
        let record = try insert(AlarmConfiguration(isEnabled: false))

        XCTAssertNotNil(AlarmRecord.challenge(for: record.id, in: context))
    }

    func testUnknownAlarmShowsNoticeInsteadOfNavigating() {
        let router = makeActivatedRouter()

        router.receive(alarmID: UUID())

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertTrue(router.isShowingUnavailableAlarmNotice)
        XCTAssertNil(makeStore().load(), "invalid request is not retried forever")
    }

    func testDeletedAlarmShowsNoticeInsteadOfNavigating() throws {
        let record = try insert(AlarmConfiguration())
        let id = record.id
        context.delete(record)
        try context.save()
        let router = makeActivatedRouter()

        router.receive(alarmID: id)

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertTrue(router.isShowingUnavailableAlarmNotice)
    }

    func testChallengeReplacesPracticeWorkout() throws {
        let record = try insert(AlarmConfiguration())
        let router = makeActivatedRouter()
        router.path = [.manualWorkout]

        router.receive(alarmID: record.id)

        XCTAssertEqual(router.path, [.alarmChallenge(record.id)])
    }

    func testDifferentAlarmReplacesCurrentChallenge() throws {
        let first = try insert(AlarmConfiguration(title: "First"))
        let second = try insert(AlarmConfiguration(title: "Second"))
        let router = makeActivatedRouter()

        router.receive(alarmID: first.id)
        currentDate.addTimeInterval(5)
        router.receive(alarmID: second.id)

        XCTAssertEqual(router.path, [.alarmChallenge(second.id)])
    }

    // MARK: - Cold launch

    func testRequestBeforeUIIsReadyIsDeliveredOnActivation() throws {
        let record = try insert(AlarmConfiguration())
        let router = makeRouter()

        router.receive(alarmID: record.id)
        XCTAssertTrue(router.path.isEmpty, "can't resolve without the model context")

        activate(router)
        XCTAssertEqual(router.path, [.alarmChallenge(record.id)])
    }

    func testRequestSurvivesProcessRestart() throws {
        let record = try insert(AlarmConfiguration())
        // Intent ran, then the process died before the UI appeared.
        makeRouter().receive(alarmID: record.id)

        let relaunched = makeActivatedRouter()

        XCTAssertEqual(relaunched.path, [.alarmChallenge(record.id)])
        XCTAssertNil(makeStore().load())
    }

    func testStaleRequestIsDroppedOnLaunch() throws {
        let record = try insert(AlarmConfiguration())
        makeRouter().receive(alarmID: record.id)
        currentDate.addTimeInterval(AlarmChallengeRouter.requestLifetime + 1)

        let relaunched = makeActivatedRouter()

        XCTAssertTrue(relaunched.path.isEmpty)
        XCTAssertFalse(relaunched.isShowingUnavailableAlarmNotice)
        XCTAssertNil(makeStore().load())
    }

    func testCorruptStoredRequestIsDiscarded() {
        defaults.set(Data("garbage".utf8), forKey: storeKey)

        let router = makeActivatedRouter()

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertNil(defaults.data(forKey: storeKey))
    }

    // MARK: - Duplicates

    func testRepeatedDeliveryDoesNotPushTwice() throws {
        let record = try insert(AlarmConfiguration())
        let router = makeActivatedRouter()

        router.receive(alarmID: record.id)
        router.receive(alarmID: record.id)
        router.deliverPendingRequest()

        XCTAssertEqual(router.path, [.alarmChallenge(record.id)])
    }

    func testRepeatedDeliveryBeforeActivationOpensOnce() throws {
        let record = try insert(AlarmConfiguration())
        let router = makeRouter()

        router.receive(alarmID: record.id)
        router.receive(alarmID: record.id)
        activate(router)
        router.deliverPendingRequest()

        XCTAssertEqual(router.path, [.alarmChallenge(record.id)])
    }

    func testLateDuplicateAfterDismissalDoesNotReopen() throws {
        let record = try insert(AlarmConfiguration())
        let router = makeActivatedRouter()
        router.receive(alarmID: record.id)
        router.dismissChallenge()

        currentDate.addTimeInterval(5)
        router.receive(alarmID: record.id)

        XCTAssertTrue(router.path.isEmpty)
    }

    func testSameAlarmRingingAgainLaterReopens() throws {
        let record = try insert(AlarmConfiguration(repeatDays: .everyDay))
        let router = makeActivatedRouter()
        router.receive(alarmID: record.id)
        router.dismissChallenge()

        currentDate.addTimeInterval(24 * 60 * 60)
        router.receive(alarmID: record.id)

        XCTAssertEqual(router.path, [.alarmChallenge(record.id)])
    }

    // MARK: - Dismissal

    func testDismissReturnsHomeAndIsIdempotent() throws {
        let record = try insert(AlarmConfiguration())
        let router = makeActivatedRouter()
        router.receive(alarmID: record.id)

        router.dismissChallenge()
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertNil(router.activeChallengeID)

        router.dismissChallenge()
        XCTAssertTrue(router.path.isEmpty)
    }

    func testForegroundingAfterDismissalDoesNotReopen() throws {
        let record = try insert(AlarmConfiguration())
        let router = makeActivatedRouter()
        router.receive(alarmID: record.id)
        router.dismissChallenge()

        router.deliverPendingRequest()

        XCTAssertTrue(router.path.isEmpty)
    }

    func testDismissLeavesNonChallengeRoutes() {
        let router = makeActivatedRouter()
        router.path = [.manualWorkout]

        router.dismissChallenge()

        XCTAssertEqual(router.path, [.manualWorkout])
    }

    // MARK: - Helpers

    private let storeKey = "pendingAlarmChallengeRequest"

    private func makeStore() -> AlarmChallengeRequestStore {
        AlarmChallengeRequestStore(defaults: defaults, key: storeKey)
    }

    private func makeRouter() -> AlarmChallengeRouter {
        AlarmChallengeRouter(store: makeStore(), now: { [unowned self] in self.currentDate })
    }

    private func makeActivatedRouter() -> AlarmChallengeRouter {
        let router = makeRouter()
        activate(router)
        return router
    }

    private func activate(_ router: AlarmChallengeRouter) {
        let context = context
        router.activate { AlarmRecord.challenge(for: $0, in: context) }
    }

    @discardableResult
    private func insert(_ configuration: AlarmConfiguration) throws -> AlarmRecord {
        let record = try AlarmRecord(configuration: configuration)
        context.insert(record)
        try context.save()
        return record
    }
}
