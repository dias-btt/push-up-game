//
//  WeekdaySet.swift
//  PushUpGame
//

import Foundation

/// Raw values match `Calendar`'s `weekday` component (Sunday = 1 … Saturday = 7)
/// so conversion to system scheduling APIs never needs a lookup table.
nonisolated enum Weekday: Int, CaseIterable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    /// Weekdays in display order for `calendar`, honouring its `firstWeekday`
    /// (e.g. Monday-first in most of Europe, Sunday-first in the US).
    static func ordered(for calendar: Calendar) -> [Weekday] {
        let startIndex = max(0, min(calendar.firstWeekday - 1, allCases.count - 1))
        return Array(allCases[startIndex...] + allCases[..<startIndex])
    }
}

/// Repeat days for an alarm, persisted as a 7-bit mask (bit 0 = Sunday).
/// An empty set means a one-time alarm.
nonisolated struct WeekdaySet: OptionSet, Hashable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(_ weekday: Weekday) {
        self.init(rawValue: 1 << (weekday.rawValue - 1))
    }

    init<S: Sequence>(_ weekdays: S) where S.Element == Weekday {
        self = weekdays.reduce(into: WeekdaySet()) { $0.insert(WeekdaySet($1)) }
    }

    /// Rejects masks with bits outside the seven weekdays instead of silently
    /// dropping them, so corrupted or future-format data is noticed.
    init(validatingRawValue rawValue: Int) throws {
        guard rawValue & ~Self.everyDay.rawValue == 0 else {
            throw AlarmValidationError.invalidRepeatDays(rawValue: rawValue)
        }
        self.init(rawValue: rawValue)
    }

    static let everyDay = WeekdaySet(rawValue: 0b111_1111)
    static let weekdays = WeekdaySet([.monday, .tuesday, .wednesday, .thursday, .friday])
    static let weekends = WeekdaySet([.saturday, .sunday])

    var isOneTime: Bool { isEmpty }

    var isValid: Bool { rawValue & ~Self.everyDay.rawValue == 0 }

    func contains(_ weekday: Weekday) -> Bool {
        contains(WeekdaySet(weekday))
    }

    mutating func toggle(_ weekday: Weekday) {
        let member = WeekdaySet(weekday)
        if contains(member) {
            remove(member)
        } else {
            insert(member)
        }
    }

    /// Selected weekdays in `calendar` display order.
    func sortedWeekdays(for calendar: Calendar) -> [Weekday] {
        Weekday.ordered(for: calendar).filter { contains($0) }
    }

    /// Short human-readable description, e.g. "Every day", "Weekdays", "Mon, Wed".
    func summary(calendar: Calendar) -> String {
        switch self {
        case []:
            return "Once"
        case .everyDay:
            return "Every day"
        case .weekdays:
            return "Weekdays"
        case .weekends:
            return "Weekends"
        default:
            let symbols = calendar.shortWeekdaySymbols
            return sortedWeekdays(for: calendar)
                .map { symbols[$0.rawValue - 1] }
                .joined(separator: ", ")
        }
    }
}
