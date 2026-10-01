import Foundation

enum GitStatusParser {
    static func parse(porcelainZ output: String) -> GitWorkingTreeStatus {
        var tracked: [GitFileChange] = []
        var untracked: [String] = []

        let tokens = output.split(separator: "\0", omittingEmptySubsequences: true).map { String($0) }
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            index += 1

            guard token.count > 3 else {
                continue
            }

            let code = String(token.prefix(2))
            let path = String(token.dropFirst(3))

            guard code != "??" else {
                untracked.append(path)
                continue
            }
            guard code != "!!" else {
                continue
            }
            guard let status = status(for: code) else {
                continue
            }

            switch status {
            case .renamed,
                 .copied:
                let originalPath = index < tokens.count ? tokens[index] : nil
                index += 1
                tracked.append(GitFileChange(path: path, status: status, originalPath: originalPath))
            case .added,
                 .modified,
                 .deleted,
                 .typeChanged,
                 .conflicted,
                 .untracked:
                tracked.append(GitFileChange(path: path, status: status))
            }
        }

        return GitWorkingTreeStatus(trackedChanges: tracked, untrackedPaths: untracked)
    }

    // MARK: - Helpers

    private static let conflictCodes: Set<String> = ["DD", "AU", "UD", "UA", "DU", "AA", "UU"]

    private static func status(for code: String) -> GitChangeStatus? {
        guard conflictCodes.contains(code) == false else {
            return .conflicted
        }

        let letters = Set(code.filter { $0 != " " })

        guard letters.isEmpty == false else {
            return nil
        }

        if letters.contains("R") {
            return .renamed
        }

        if letters.contains("C") {
            return .copied
        }

        if letters.contains("D") {
            return .deleted
        }

        if letters.contains("A") {
            return .added
        }

        if letters.contains("T") {
            return .typeChanged
        }

        if letters.contains("M") {
            return .modified
        }

        return nil
    }
}
