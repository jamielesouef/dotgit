import Foundation

enum WIPCommitMessageUseCase {
    static func prefix(repositoryOverride: String?, appWide: String?) -> String {
        guard let repositoryOverride = trimmed(repositoryOverride) else {
            return trimmed(appWide) ?? AppPreferences.fallbackWIPCommitPrefix
        }

        return repositoryOverride
    }

    static func appendsTimestamp(appWide: Bool, repositoryOmits: Bool) -> Bool {
        appWide && repositoryOmits == false
    }

    static func message(
        repositoryOverride: String?,
        appWide: String?,
        timestamp: Date,
        timeZone: TimeZone,
        appendsTimestamp: Bool
    ) -> String {
        let prefix = prefix(repositoryOverride: repositoryOverride, appWide: appWide)

        guard appendsTimestamp else {
            return prefix
        }

        return "\(prefix) \(formatted(timestamp, timeZone: timeZone))"
    }

    // MARK: - Helpers

    private static func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }

        return value
    }

    private static func formatted(_ timestamp: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = timeZone

        return formatter.string(from: timestamp)
    }
}
