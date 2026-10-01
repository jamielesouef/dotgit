import Foundation
@testable import dotgit

actor StubCommandRunner: CommandRunning {
    // MARK: - Private

    private var matchers: [(prefix: [String], outcome: Result<CommandResult, CommandError>)] = []
    private var fallback: CommandResult = .init(exitCode: 0, standardOutput: "", standardError: "")

    private(set) var requests: [CommandRequest] = []

    // MARK: - Configuration

    func stub(_ prefix: [String], output: String = "", exitCode: Int32 = 0, error standardError: String = "") {
        matchers.append((
            prefix,
            .success(CommandResult(exitCode: exitCode, standardOutput: output, standardError: standardError))
        ))
    }

    func stub(_ prefix: [String], failure: CommandError) {
        matchers.append((prefix, .failure(failure)))
    }

    func setFallback(_ result: CommandResult) {
        fallback = result
    }

    // MARK: - Inspection

    var argumentLists: [[String]] {
        requests.map(\.arguments)
    }

    func containsArguments(_ prefix: [String]) -> Bool {
        requests.contains { Self.matches(arguments: $0.arguments, prefix: prefix) }
    }

    // MARK: - CommandRunning

    func run(_ request: CommandRequest) async throws(CommandError) -> CommandResult {
        requests.append(request)

        guard let matcher = matchers.last(where: { Self.matches(arguments: request.arguments, prefix: $0.prefix) })
        else {
            return fallback
        }

        switch matcher.outcome {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }

    // MARK: - Helpers

    private static func matches(arguments: [String], prefix: [String]) -> Bool {
        guard prefix.count <= arguments.count else {
            return false
        }

        return Array(arguments.prefix(prefix.count)) == prefix
    }
}
