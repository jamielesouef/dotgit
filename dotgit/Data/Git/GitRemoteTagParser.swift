import Foundation

enum GitRemoteTagParser {
    static func tagNames(fromLsRemote output: String) -> Set<String> {
        var names: Set<String> = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: true)

            guard fields.count >= 2 else {
                continue
            }

            var reference = String(fields[1])

            guard reference.hasPrefix("refs/tags/") else {
                continue
            }

            reference.removeFirst("refs/tags/".count)

            guard reference.hasSuffix("^{}") == false else {
                names.insert(String(reference.dropLast(3)))
                continue
            }

            names.insert(reference)
        }

        return names
    }

    static func unpushedTags(local: [String], remote: Set<String>) -> [String] {
        local.filter { remote.contains($0) == false }
    }
}
