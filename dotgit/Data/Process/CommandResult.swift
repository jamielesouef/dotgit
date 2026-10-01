import Foundation

struct CommandResult: Equatable {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String

    var succeeded: Bool {
        exitCode == 0
    }

    var trimmedOutput: String {
        standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var outputLines: [String] {
        standardOutput
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }
    }

    var failureMessage: String {
        let stderr = standardError.trimmingCharacters(in: .whitespacesAndNewlines)

        guard stderr.isEmpty else {
            return stderr
        }

        return trimmedOutput
    }
}
