//
//  PushUpState.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation

enum PushUpState: Equatable, Sendable {
    case unknown
    case ready
    case up
    case descending
    case down
    case ascending
}
