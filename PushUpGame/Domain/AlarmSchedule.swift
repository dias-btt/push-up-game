//
//  AlarmSchedule.swift
//  PushUpGame
//

import Foundation

/// The part of an alarm the system scheduler cares about: a wall-clock time
/// and the weekdays it repeats on (empty = one-time).
///
/// Mirrors a *relative* system schedule on purpose: relative schedules follow
/// the device's current time zone and DST rules, so 07:00 rings at 07:00 local
/// time after travel or a clock change. A fixed `Date` schedule would not.
nonisolated struct AlarmSchedule: Hashable, Sendable {
    let time: AlarmTime
    let weekdays: WeekdaySet

    init(time: AlarmTime, weekdays: WeekdaySet) {
        self.time = time
        // Unknown bits would be meaningless to the system scheduler.
        self.weekdays = weekdays.intersection(.everyDay)
    }

    init(configuration: AlarmConfiguration) {
        self.init(time: configuration.time, weekdays: configuration.repeatDays)
    }

    var isOneTime: Bool { weekdays.isOneTime }

    /// Weekdays in a fixed Sunday-first order so the system receives a
    /// deterministic list regardless of locale.
    var localeWeekdays: [Locale.Weekday] {
        Weekday.allCases.filter { weekdays.contains($0) }.map(\.localeWeekday)
    }

    init(time: AlarmTime, localeWeekdays: [Locale.Weekday]) {
        self.init(time: time, weekdays: WeekdaySet(localeWeekdays.map(Weekday.init(localeWeekday:))))
    }

    /// When a one-time schedule armed at `armedAt` rings: the next occurrence
    /// of its wall-clock time. Uses `.nextTime` so a time skipped by a DST jump
    /// resolves to the next valid instant instead of `nil`.
    func oneTimeFireDate(afterArmingAt armedAt: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(
            after: armedAt,
            matching: DateComponents(hour: time.hour, minute: time.minute, second: 0),
            matchingPolicy: .nextTime
        )
    }
}

nonisolated extension Weekday {
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }

    init(localeWeekday: Locale.Weekday) {
        switch localeWeekday {
        case .sunday: self = .sunday
        case .monday: self = .monday
        case .tuesday: self = .tuesday
        case .wednesday: self = .wednesday
        case .thursday: self = .thursday
        case .friday: self = .friday
        case .saturday: self = .saturday
        @unknown default:
            // Locale.Weekday has exactly seven cases today; a new one would
            // be a Foundation change we'd need to handle explicitly.
            self = .sunday
        }
    }
}
