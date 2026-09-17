//
//  PushUpEvent.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation

enum PushUpEvent: Equatable, Sendable {
    case repCompleted
    case stateChanged(to: PushUpState)
    case positionInvalid(reason: String)
}
