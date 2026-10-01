import Foundation

struct SimctlRuntimeProvider: SimulatorRuntimeProviding {
    // MARK: - Private

    private let commandRunner: any CommandRunning
    private let xcrunPath: String

    // MARK: - Init

    init(commandRunner: any CommandRunning, xcrunPath: String) {
        self.commandRunner = commandRunner
        self.xcrunPath = xcrunPath
    }

    // MARK: - SimulatorRuntimeProviding

    func runtimes() async -> [SimulatorRuntime] {
        let request = CommandRequest(
            executablePath: xcrunPath,
            arguments: ["simctl", "runtime", "list", "--json"]
        )

        guard let result = try? await commandRunner.run(request), result.succeeded else {
            return []
        }

        return SimulatorRuntimeParser.parse(result.standardOutput)
    }

    func delete(identifier: String) async throws(CleanupError) {
        let request = CommandRequest(
            executablePath: xcrunPath,
            arguments: ["simctl", "runtime", "delete", identifier]
        )

        let result: CommandResult

        do {
            result = try await commandRunner.run(request)
        } catch {
            throw .toolUnavailable
        }

        guard result.succeeded else {
            throw .removalFailed(result.failureMessage)
        }
    }
}
