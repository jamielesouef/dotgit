import Foundation

enum GitSubmoduleParser {
    static func parse(statusOutput output: String) -> [GitSubmoduleChange] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { change(from: String($0)) }
    }

    // MARK: - Helpers

    private static func change(from line: String) -> GitSubmoduleChange? {
        guard let marker = line.first else {
            return nil
        }

        let kind: GitSubmoduleChange.Kind

        switch marker {
        case "+":
            kind = .commitDiffers
        case "-":
            kind = .uninitialised
        case "U":
            kind = .mergeConflict
        default:
            return nil
        }

        let fields = line
            .dropFirst()
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }

        guard fields.count >= 2 else {
            return nil
        }

        return GitSubmoduleChange(path: fields[1], kind: kind)
    }
}
