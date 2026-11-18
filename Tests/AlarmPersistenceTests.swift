//
//  AlarmPersistenceTests.swift
//  PushUpGameTests
//

import SwiftData
import XCTest

@testable import PushUpGame

/// Each test gets its own in-memory container built from the app's schema,
/// so tests are isolated from each other and from the on-device store.
@MainActor
final class AlarmPersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try AppDependencies.makeModelContainer(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    func testCreateAndFetch() throws {
        let configuration = AlarmConfiguration(
            title: "Wake up",
            time: try AlarmTime(hour: 6, minute: 30),
            repeatDays: .weekdays,
            pushUpTarget: 25
        )
        let record = try AlarmRecord(configuration: configuration)
        context.insert(record)
        try context.save()

        let fetched = try fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, record.id)
        XCTAssertEqual(fetched.first?.configuration, configuration)
        XCTAssertEqual(fetched.first?.repeatDaysRawValue, WeekdaySet.weekdays.rawValue)
    }

    func testCreateRejectsInvalidConfiguration() throws {
        XCTAssertThrowsError(try AlarmRecord(configuration: AlarmConfiguration(pushUpTarget: 0)))
        XCTAssertTrue(try fetchAll().isEmpty)
    }

    func testCreateStoresNormalizedTitle() throws {
        let record = try AlarmRecord(configuration: AlarmConfiguration(title: "  Gym  "))
        XCTAssertEqual(record.title, "Gym")
    }

    func testUpdatePersistsChanges() throws {
        let record = try AlarmRecord(configuration: AlarmConfiguration())
        context.insert(record)
        try context.save()

        var edited = record.configuration
        edited.title = "Edited"
        edited.time = try AlarmTime(hour: 21, minute: 15)
        edited.repeatDays = WeekdaySet(.saturday)
        edited.pushUpTarget = 40
        try record.update(with: edited)
        try context.save()

        let fetched = try XCTUnwrap(fetchAll().first)
        XCTAssertEqual(fetched.configuration, edited)
    }

    func testInvalidUpdateLeavesRecordUnchanged() throws {
        let original = AlarmConfiguration(title: "Original", pushUpTarget: 15)
        let record = try AlarmRecord(configuration: original)
        context.insert(record)

        var invalid = original
        invalid.title = "Changed"
        invalid.pushUpTarget = 0

        XCTAssertThrowsError(try record.update(with: invalid))
        XCTAssertEqual(record.configuration, original)
    }

    func testToggleEnabledPersists() throws {
        let record = try AlarmRecord(configuration: AlarmConfiguration())
        context.insert(record)
        try context.save()

        record.isEnabled = false
        try context.save()

        let fetched = try XCTUnwrap(fetchAll().first)
        XCTAssertFalse(fetched.isEnabled)
        XCTAssertEqual(fetched.schedulingStatus, .off)
    }

    func testDelete() throws {
        let keep = try AlarmRecord(configuration: AlarmConfiguration(title: "Keep"))
        let remove = try AlarmRecord(configuration: AlarmConfiguration(title: "Remove"))
        context.insert(keep)
        context.insert(remove)
        try context.save()

        context.delete(remove)
        try context.save()

        XCTAssertEqual(try fetchAll().map(\.title), ["Keep"])
    }

    func testListSortIsByTimeThenCreationDate() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let late = try AlarmRecord(
            configuration: AlarmConfiguration(title: "late", time: try AlarmTime(hour: 9, minute: 0)),
            createdAt: base
        )
        let earlyNewer = try AlarmRecord(
            configuration: AlarmConfiguration(title: "early-newer", time: try AlarmTime(hour: 6, minute: 0)),
            createdAt: base.addingTimeInterval(10)
        )
        let earlyOlder = try AlarmRecord(
            configuration: AlarmConfiguration(title: "early-older", time: try AlarmTime(hour: 6, minute: 0)),
            createdAt: base
        )
        [late, earlyNewer, earlyOlder].forEach(context.insert)
        try context.save()

        XCTAssertEqual(try fetchAll().map(\.title), ["early-older", "early-newer", "late"])
    }

    /// Simulates an app restart: a second container opening the same on-disk store
    /// sees the alarm saved by the first.
    func testAlarmsSurviveContainerRecreation() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlarmPersistenceTests-\(UUID().uuidString).store")
        defer { Self.removeStore(at: storeURL) }

        let id: UUID
        do {
            let first = try Self.makeOnDiskContainer(url: storeURL)
            let record = try AlarmRecord(configuration: AlarmConfiguration(title: "Persisted", pushUpTarget: 30))
            id = record.id
            first.mainContext.insert(record)
            try first.mainContext.save()
        }

        let second = try Self.makeOnDiskContainer(url: storeURL)
        let fetched = try second.mainContext.fetch(FetchDescriptor<AlarmRecord>())
        XCTAssertEqual(fetched.map(\.id), [id])
        XCTAssertEqual(fetched.first?.pushUpTarget, 30)
    }

    private func fetchAll() throws -> [AlarmRecord] {
        try context.fetch(FetchDescriptor<AlarmRecord>(sortBy: AlarmRecord.listSortDescriptors))
    }

    private static func makeOnDiskContainer(url: URL) throws -> ModelContainer {
        let schema = AppDependencies.persistentSchema
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
    }

    private static func removeStore(at url: URL) {
        // SQLite keeps -wal/-shm side files next to the store.
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
