//
//  AlarmRecord.swift
//  PushUpGame
//

import Foundation
import SwiftData

/// Persisted alarm configuration.
///
/// Named `AlarmRecord` rather than `Alarm` to avoid colliding with AlarmKit's
/// `Alarm` type once system scheduling is added.
///
/// Stores primitives (hour, minute, weekday bitmask) instead of `Date` or a
/// Codable struct so the on-disk schema stays stable and queryable. Validated
/// fields are only writable through `init(configuration:)` and
/// `update(with:)`, so invalid values cannot be persisted from the UI.
///
/// Holds no scheduling state on purpose — see `AlarmSchedulingStatus`.
@Model
final class AlarmRecord {
    @Attribute(.unique) private(set) var id: UUID
    private(set) var title: String
    private(set) var hour: Int
    private(set) var minute: Int
    private(set) var repeatDaysRawValue: Int
    private(set) var pushUpTarget: Int
    var isEnabled: Bool
    private(set) var createdAt: Date

    init(configuration: AlarmConfiguration, id: UUID = UUID(), createdAt: Date = .now) throws {
        let valid = try configuration.validated()
        self.id = id
        self.title = valid.title
        self.hour = valid.time.hour
        self.minute = valid.time.minute
        self.repeatDaysRawValue = valid.repeatDays.rawValue
        self.pushUpTarget = valid.pushUpTarget
        self.isEnabled = valid.isEnabled
        self.createdAt = createdAt
    }

    /// Replaces all user-editable fields. Throws without mutating anything if
    /// the configuration is invalid.
    func update(with configuration: AlarmConfiguration) throws {
        let valid = try configuration.validated()
        title = valid.title
        hour = valid.time.hour
        minute = valid.time.minute
        repeatDaysRawValue = valid.repeatDays.rawValue
        pushUpTarget = valid.pushUpTarget
        isEnabled = valid.isEnabled
    }

    /// Every write is validated, so out-of-range values here could only come from
    /// a bug or a future schema change. Clamping keeps the list renderable in that
    /// case rather than crashing or hiding the alarm.
    var configuration: AlarmConfiguration {
        AlarmConfiguration(
            title: title,
            time: time,
            repeatDays: repeatDays,
            pushUpTarget: min(
                max(pushUpTarget, AlarmConfiguration.pushUpTargetRange.lowerBound),
                AlarmConfiguration.pushUpTargetRange.upperBound
            ),
            isEnabled: isEnabled
        )
    }

    var time: AlarmTime {
        AlarmTime(clampingHour: hour, minute: minute)
    }

    var repeatDays: WeekdaySet {
        WeekdaySet(rawValue: repeatDaysRawValue).intersection(.everyDay)
    }

    var schedulingStatus: AlarmSchedulingStatus {
        AlarmSchedulingStatus(isEnabled: isEnabled)
    }

    /// Default ordering for lists: by time of day, then oldest first for ties.
    static let listSortDescriptors: [SortDescriptor<AlarmRecord>] = [
        SortDescriptor(\.hour),
        SortDescriptor(\.minute),
        SortDescriptor(\.createdAt),
    ]
}
