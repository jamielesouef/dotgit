import Foundation

enum GitLogParser {
    static let format = "%H%1F%s%1F%an%1F%cI"

    static func parse(logOutput output: String) -> [GitCommitSummary] {
        let formatter = ISO8601DateFormatter()

        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { commit(from: String($0), formatter: formatter) }
    }

    // MARK: - Helpers

    private static func commit(from line: String, formatter: ISO8601DateFormatter) -> GitCommitSummary? {
        let fields = line.components(separatedBy: "\u{1F}")

        guard fields.count >= 4, fields[0].isEmpty == false else {
            return nil
        }

        return GitCommitSummary(
            hash: fields[0],
            subject: fields[1],
            authorName: fields[2],
            date: formatter.date(from: fields[3]) ?? .distantPast
        )
    }
}
