//
//  AlarmConfiguration.swift
//  PushUpGame
//

import Foundation

/// What the user asked for: the alarm's settings, independent of persistence
/// and of whether the system has actually scheduled it (see `AlarmSchedulingStatus`).
nonisolated struct AlarmConfiguration: Equatable, Sendable {
    static let defaultPushUpTarget = 10
    /// Upper bound keeps a half-asleep user from locking themselves into an
    /// unreachable target; the lower bound keeps the challenge meaningful.
    static let pushUpTargetRange = 1...100
    static let maximumTitleLength = 60
    static let fallbackTitle = "Alarm"

    var title: String
    var time: AlarmTime
    var repeatDays: WeekdaySet
    var pushUpTarget: Int
    var isEnabled: Bool

    init(
        title: String = "",
        time: AlarmTime = .wakeUpDefault,
        repeatDays: WeekdaySet = [],
        pushUpTarget: Int = AlarmConfiguration.defaultPushUpTarget,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.time = time
        self.repeatDays = repeatDays
        self.pushUpTarget = pushUpTarget
        self.isEnabled = isEnabled
    }

    var isOneTime: Bool { repeatDays.isOneTime }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.fallbackTitle : trimmed
    }

    /// Returns a normalized copy (trimmed title), or throws the first rule violated.
    func validated() throws -> AlarmConfiguration {
        var normalized = self
        normalized.title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.title.count <= Self.maximumTitleLength else {
            throw AlarmValidationError.titleTooLong(maximumLength: Self.maximumTitleLength)
        }
        guard Self.pushUpTargetRange.contains(pushUpTarget) else {
            throw AlarmValidationError.pushUpTargetOutOfRange(pushUpTarget)
        }
        guard repeatDays.isValid else {
            throw AlarmValidationError.invalidRepeatDays(rawValue: repeatDays.rawValue)
        }
        return normalized
    }

    var validationError: AlarmValidationError? {
        do {
            _ = try validated()
            return nil
        } catch let error as AlarmValidationError {
            return error
        } catch {
            // validated() only throws AlarmValidationError.
            return nil
        }
    }
}
