//
//  AlarmTime.swift
//  PushUpGame
//

import Foundation

/// Wall-clock time of day for an alarm, independent of any absolute date.
///
/// Stored as hour/minute rather than `Date` so that "07:00" stays 07:00 across
/// DST transitions and time-zone changes — the same semantics as system alarms.
/// A `Date` would pin the alarm to an instant and silently drift by an hour.
nonisolated struct AlarmTime: Hashable, Comparable, Sendable {
    static let hourRange = 0...23
    static let minuteRange = 0...59

    /// Default for new alarms; this is a wake-up app.
    static let wakeUpDefault = AlarmTime(uncheckedHour: 7, minute: 0)

    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) throws {
        guard Self.hourRange.contains(hour) else { throw AlarmValidationError.invalidHour(hour) }
        guard Self.minuteRange.contains(minute) else { throw AlarmValidationError.invalidMinute(minute) }
        self.init(uncheckedHour: hour, minute: minute)
    }

    /// Extracts the wall-clock time of `date` in `calendar`'s time zone.
    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        // Calendar always yields in-range hour/minute; clamping only guards against
        // a missing component, which would otherwise need a force unwrap.
        self.init(clampingHour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    /// Clamps out-of-range values into range. Used only when decoding persisted
    /// data, where every write already went through validation.
    init(clampingHour hour: Int, minute: Int) {
        self.init(
            uncheckedHour: min(max(hour, Self.hourRange.lowerBound), Self.hourRange.upperBound),
            minute: min(max(minute, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        )
    }

    private init(uncheckedHour hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }

    /// This time of day on the same calendar day as `day`. Returns `nil` when the
    /// wall-clock time does not exist on that day (skipped by a DST transition).
    func date(onSameDayAs day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    static func < (lhs: AlarmTime, rhs: AlarmTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}
