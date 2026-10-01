import Foundation

enum GitAheadBehindParser {
    static func parse(revListOutput output: String) -> (ahead: Int, behind: Int) {
        let fields = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == "\t" || $0 == " " })
            .compactMap { Int($0) }

        guard fields.count >= 2 else {
            return (0, 0)
        }

        return (ahead: fields[1], behind: fields[0])
    }
}
