import Foundation

enum GitWorktreeParser {
    // MARK: - Worktree list

    static func parse(porcelain output: String) -> [GitWorktree] {
        let blocks = output
            .components(separatedBy: "\n\n")
            .map { $0.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) }
            .filter { $0.isEmpty == false }

        return blocks.enumerated().compactMap { index, lines in
            worktree(from: lines, isMain: index == 0)
        }
    }

    // MARK: - Git file

    static func isLinkedWorktreePointer(_ gitFileContents: String) -> Bool {
        let prefix = "gitdir:"
        let line = gitFileContents.trimmingCharacters(in: .whitespacesAndNewlines)

        guard line.hasPrefix(prefix) else {
            return false
        }

        let gitDirectory = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)

        return gitDirectory.contains("/worktrees/")
    }

    // MARK: - Helpers

    private static func worktree(from lines: [String], isMain: Bool) -> GitWorktree? {
        guard let pathLine = lines.first(where: { $0.hasPrefix("worktree ") }) else {
            return nil
        }

        let path = String(pathLine.dropFirst("worktree ".count))
        let head = value(for: "HEAD", in: lines)
        let branch = value(for: "branch", in: lines).map(shortBranchName)

        return GitWorktree(
            path: URL(filePath: path),
            headCommit: head,
            branch: branch,
            isMain: isMain,
            isBare: lines.contains("bare"),
            isLocked: lines.contains { $0 == "locked" || $0.hasPrefix("locked ") },
            isPrunable: lines.contains { $0 == "prunable" || $0.hasPrefix("prunable ") }
        )
    }

    private static func value(for key: String, in lines: [String]) -> String? {
        let prefix = key + " "

        return lines.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }

    private static func shortBranchName(_ reference: String) -> String {
        let prefix = "refs/heads/"

        guard reference.hasPrefix(prefix) else {
            return reference
        }

        return String(reference.dropFirst(prefix.count))
    }
}
