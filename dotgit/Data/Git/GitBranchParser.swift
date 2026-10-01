import Foundation

enum GitBranchParser {
    static let format = "%(refname:short)%1F%(upstream:short)%1F%(upstream:track)"

    static func parse(forEachRef output: String) -> [GitBranchRef] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { branch(from: String($0)) }
    }

    static func aheadBehind(fromTrack track: String) -> (ahead: Int, behind: Int) {
        (count(in: track, after: "ahead "), count(in: track, after: "behind "))
    }

    // MARK: - Helpers

    private static func branch(from line: String) -> GitBranchRef? {
        let fields = line.components(separatedBy: "\u{1F}")

        guard fields.count >= 3 else {
            return nil
        }

        let name = fields[0].trimmingCharacters(in: .whitespaces)

        guard name.isEmpty == false else {
            return nil
        }

        let upstreamField = fields[1].trimmingCharacters(in: .whitespaces)
        let counts = aheadBehind(fromTrack: fields[2])

        return GitBranchRef(
            name: name,
            upstream: upstreamField.isEmpty ? nil : upstreamField,
            aheadCount: counts.ahead,
            behindCount: counts.behind
        )
    }

    private static func count(in track: String, after keyword: String) -> Int {
        guard let range = track.range(of: keyword) else {
            return 0
        }

        let digits = track[range.upperBound...].prefix { $0.isNumber }

        return Int(digits) ?? 0
    }
}
