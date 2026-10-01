import Foundation

enum SSHResolvedConfigParser {
    /// Reads the `hostname` line from `ssh -G` output.
    static func hostName(from output: String) -> String? {
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = rawLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)

            guard fields.count == 2, fields[0].lowercased() == "hostname" else {
                continue
            }

            let hostName = fields[1].trimmingCharacters(in: .whitespaces)

            return hostName.isEmpty ? nil : hostName
        }

        return nil
    }
}
