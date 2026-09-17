//
//  Geometry.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import CoreGraphics
import Foundation

/// Angle in degrees at `vertex` between segments `vertex→pointA` and `vertex→pointB`.
///
/// Uses `atan2(|u×v|, u·v)` for stability near 0° and 180°. Result is in `[0, 180]`.
///
/// Degenerate cases (zero-length arm): if `vertex` equals `pointA` or `pointB`, the
/// corresponding vector is zero, both dot and cross are zero, and this returns `0`.
func angle(at vertex: CGPoint, between pointA: CGPoint, and pointB: CGPoint) -> Double {
    let vectorA = subtract(pointA, from: vertex)
    let vectorB = subtract(pointB, from: vertex)

    let dotProduct = dot(vectorA, vectorB)
    let crossMagnitude = abs(crossZ(vectorA, vectorB))
    let radians = atan2(crossMagnitude, dotProduct)
    let degrees = radians * 180 / .pi

    return min(180, max(0, degrees))
}

private func subtract(_ point: CGPoint, from origin: CGPoint) -> CGPoint {
    CGPoint(x: point.x - origin.x, y: point.y - origin.y)
}

private func dot(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
    lhs.x * rhs.x + lhs.y * rhs.y
}

/// Signed z-component of the 2D cross product `lhs × rhs`.
private func crossZ(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
    lhs.x * rhs.y - lhs.y * rhs.x
}
