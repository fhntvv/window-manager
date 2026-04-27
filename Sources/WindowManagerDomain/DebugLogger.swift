import Foundation
@preconcurrency import os

public struct DebugLogger: Sendable {
    nonisolated(unsafe) public static var isDebugMode = false

    private let logger: Logger
    private let category: String

    public init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    public func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        if Self.isDebugMode { emit("DEBUG", message) }
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        if Self.isDebugMode { emit("INFO", message) }
    }

    public func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        if Self.isDebugMode { emit("WARN", message) }
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        if Self.isDebugMode { emit("ERROR", message) }
    }

    public func fault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
        if Self.isDebugMode { emit("FAULT", message) }
    }

    private func emit(_ level: String, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        fputs("[\(timestamp)] [\(category)] \(level): \(message)\n", stderr)
    }
}
