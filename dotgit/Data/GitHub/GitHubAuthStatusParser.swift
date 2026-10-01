import Foundation

enum GitHubAuthStatusParser {
    static func parse(_ output: String) -> [GitHubAccount] {
        var accounts: [(login: String, host: String)] = []
        var activeFlags: [Bool] = []

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)

            if let parsed = loggedInAccount(from: line) {
                accounts.append(parsed)
                activeFlags.append(false)
                continue
            }

            guard let isActive = activeFlag(from: line), activeFlags.isEmpty == false else {
                continue
            }

            activeFlags[activeFlags.count - 1] = isActive
        }

        return zip(accounts, activeFlags).map { account, isActive in
            GitHubAccount(login: account.login, host: account.host, isActive: isActive)
        }
    }

    // MARK: - Helpers

    private static func loggedInAccount(from line: String) -> (login: String, host: String)? {
        guard let range = line.range(of: "Logged in to ") else {
            return nil
        }

        let fields = line[range.upperBound...]
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }

        guard fields.count >= 3, fields[1] == "account" else {
            return nil
        }

        return (login: fields[2], host: fields[0])
    }

    private static func activeFlag(from line: String) -> Bool? {
        guard let range = line.range(of: "Active account:") else {
            return nil
        }

        return line[range.upperBound...].trimmingCharacters(in: .whitespaces) == "true"
    }
}
