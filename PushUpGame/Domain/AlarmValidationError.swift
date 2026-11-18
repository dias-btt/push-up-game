//
//  AlarmValidationError.swift
//  PushUpGame
//

import Foundation

nonisolated enum AlarmValidationError: Error, Equatable, Sendable, LocalizedError {
    case invalidHour(Int)
    case invalidMinute(Int)
    case invalidRepeatDays(rawValue: Int)
    case pushUpTargetOutOfRange(Int)
    case titleTooLong(maximumLength: Int)

    var errorDescription: String? {
        switch self {
        case .invalidHour(let hour):
            return "\(hour) is not a valid hour."
        case .invalidMinute(let minute):
            return "\(minute) is not a valid minute."
        case .invalidRepeatDays:
            return "The repeat days are not valid."
        case .pushUpTargetOutOfRange:
            let range = AlarmConfiguration.pushUpTargetRange
            return "Choose between \(range.lowerBound) and \(range.upperBound) push-ups."
        case .titleTooLong(let maximumLength):
            return "Labels can be at most \(maximumLength) characters."
        }
    }
}
