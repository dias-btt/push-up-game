//
//  DebugSessionLogger.swift
//  PushUpGame
//
//  Created by Диас Сайынов on 17.09.2026.
//

import Foundation

/// CSV frame log for on-device threshold tuning. Disabled in non-DEBUG builds by default.
final class DebugSessionLogger: @unchecked Sendable {
    static let shared = DebugSessionLogger()

    #if DEBUG
    static var isEnabled = true
    #else
    static let isEnabled = false
    #endif

    private let lock = NSLock()
    private var fileURL: URL?
    private var pendingLines: [String] = []
    private var framesSinceFlush = 0

    private init() {}

    func startSession() {
        guard Self.isEnabled else { return }

        lock.lock()
        defer { lock.unlock() }

        let fileName = "pushup-session-\(Self.fileNameTimestamp()).csv"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let documents else { return }

        let url = documents.appendingPathComponent(fileName)
        fileURL = url
        pendingLines = []
        framesSinceFlush = 0

        write(lines: [Self.header], to: url, append: false)
    }

    func log(update: SessionUpdate) {
        guard Self.isEnabled else { return }

        let line = Self.csvLine(for: update)
        lock.lock()
        pendingLines.append(line)
        framesSinceFlush += 1
        let shouldFlush = framesSinceFlush >= 30
        let url = fileURL
        let linesToFlush = shouldFlush ? pendingLines : []
        if shouldFlush {
            pendingLines.removeAll(keepingCapacity: true)
            framesSinceFlush = 0
        }
        lock.unlock()

        if shouldFlush, let url {
            write(lines: linesToFlush, to: url, append: true)
        }
    }

    func stopSession() {
        guard Self.isEnabled else { return }

        lock.lock()
        let url = fileURL
        let lines = pendingLines
        pendingLines = []
        framesSinceFlush = 0
        fileURL = nil
        lock.unlock()

        if let url, !lines.isEmpty {
            write(lines: lines, to: url, append: true)
        }
    }

    private func write(lines: [String], to url: URL, append: Bool) {
        let payload = lines.joined(separator: "\n") + "\n"
        guard let data = payload.data(using: .utf8) else { return }

        if append, FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static let header =
        "timestamp,left_elbow_angle,right_elbow_angle,left_confidence,right_confidence,body_line_angle,smoothed_trusted_elbow,state,trusted_side,rep_count,frames_in_state"

    private static func csvLine(for update: SessionUpdate) -> String {
        let frame = update.analyzedFrame
        return [
            iso8601(update.timestamp),
            formatOptional(frame.leftElbowAngle),
            formatOptional(frame.rightElbowAngle),
            formatOptional(frame.leftElbowConfidence),
            formatOptional(frame.rightElbowConfidence),
            formatOptional(frame.bodyLineAngle),
            formatOptional(frame.smoothedTrustedElbowAngle),
            String(describing: update.state),
            frame.trustedSide.map { String(describing: $0) } ?? "",
            String(update.repCount),
            String(update.framesInCurrentState),
        ].joined(separator: ",")
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func formatOptional(_ value: Double?) -> String {
        value.map { String(format: "%.3f", $0) } ?? ""
    }

    private static func formatOptional(_ value: Float?) -> String {
        value.map { String(format: "%.3f", $0) } ?? ""
    }

    private static func fileNameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
