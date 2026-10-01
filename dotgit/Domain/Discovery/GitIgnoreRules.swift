import Foundation

struct GitIgnoreRules: Equatable {
    // MARK: - Pattern

    struct Pattern: Equatable {
        let text: String
        let isNegated: Bool
        let directoriesOnly: Bool
        let isAnchored: Bool
    }

    // MARK: - State

    let patterns: [Pattern]

    static let empty = GitIgnoreRules(patterns: [])

    // MARK: - Parsing

    static func parse(_ contents: String) -> GitIgnoreRules {
        let patterns = contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { pattern(from: String($0)) }

        return GitIgnoreRules(patterns: patterns)
    }

    // MARK: - Matching

    func ignores(name: String, isDirectory: Bool) -> Bool {
        var ignored = false

        for pattern in patterns {
            guard pattern.directoriesOnly == false || isDirectory else {
                continue
            }
            guard matches(name: name, pattern: pattern.text) else {
                continue
            }

            ignored = pattern.isNegated == false
        }

        return ignored
    }

    func merging(_ other: GitIgnoreRules) -> GitIgnoreRules {
        GitIgnoreRules(patterns: patterns + other.patterns)
    }

    // MARK: - Helpers

    private static func pattern(from rawLine: String) -> Pattern? {
        var line = rawLine.trimmingCharacters(in: .whitespaces)

        guard line.isEmpty == false, line.hasPrefix("#") == false else {
            return nil
        }

        let isNegated = line.hasPrefix("!")

        if isNegated {
            line.removeFirst()
        }

        let directoriesOnly = line.hasSuffix("/")

        if directoriesOnly {
            line.removeLast()
        }

        let isAnchored = line.hasPrefix("/")

        if isAnchored {
            line.removeFirst()
        }

        guard line.isEmpty == false else {
            return nil
        }

        return Pattern(text: line, isNegated: isNegated, directoriesOnly: directoriesOnly, isAnchored: isAnchored)
    }

    private func matches(name: String, pattern: String) -> Bool {
        guard pattern.contains("*") || pattern.contains("?") else {
            return name == pattern
        }

        return unsafe fnmatch(pattern, name, 0) == 0
    }
}
