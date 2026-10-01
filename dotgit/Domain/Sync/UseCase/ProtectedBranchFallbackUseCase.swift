import Foundation

enum ProtectedBranchFallbackUseCase {
    static let namespace = "dotgit"

    static func branchName(for branch: String, timestamp: Date, timeZone: TimeZone) -> String {
        "\(namespace)/\(branch)-\(formatted(timestamp, timeZone: timeZone))"
    }

    // MARK: - Helpers

    private static func formatted(_ timestamp: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = timeZone

        return formatter.string(from: timestamp)
    }
}
