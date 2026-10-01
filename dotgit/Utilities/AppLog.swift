import Foundation
import OSLog

enum AppLog {
    // MARK: - Private

    private static let logger = Logger(subsystem: "mobi.jamie.dotgit", category: "app")

    // MARK: - Levels

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}
