import Foundation

struct ProcessGitHubCLIClient: GitHubCLIClienting {
    // MARK: - Private

    private let commandRunner: any CommandRunning
    private let gitHubCLIPath: String
    private let scriptRunnerPath: String

    // MARK: - Init

    init(commandRunner: any CommandRunning, gitHubCLIPath: String, scriptRunnerPath: String) {
        self.commandRunner = commandRunner
        self.gitHubCLIPath = gitHubCLIPath
        self.scriptRunnerPath = scriptRunnerPath
    }

    // MARK: - GitHubCLIClienting

    func isAvailable() async -> Bool {
        let result = try? await run(["--version"])

        return result?.succeeded == true
    }

    func accounts() async throws(GitHubCLIError) -> [GitHubAccount] {
        let result = try await run(["auth", "status"])
        let combined = result.standardOutput + "\n" + result.standardError
        let parsed = GitHubAuthStatusParser.parse(combined)

        guard parsed.isEmpty == false else {
            throw .notAuthenticated
        }

        return parsed
    }

    func switchAccount(to login: String, host: String) async throws(GitHubCLIError) {
        let result = try await run(["auth", "switch", "--hostname", host, "--user", login])

        guard result.succeeded else {
            throw .switchFailed(result.failureMessage)
        }
    }

    func hasAccess(toRemoteURL remoteURL: String) async -> Bool {
        guard let slug = GitHubRemoteParser.repositorySlug(fromRemoteURL: remoteURL) else {
            return false
        }

        let result = try? await run(["repo", "view", slug, "--json", "viewerPermission"])

        return result?.succeeded == true
    }

    func beginInteractiveSignIn() async throws(GitHubCLIError) {
        let script = "tell application \"Terminal\" to do script \"\(gitHubCLIPath) auth login\""
        let request = CommandRequest(executablePath: scriptRunnerPath, arguments: ["-e", script])

        do {
            let result = try await commandRunner.run(request)

            guard result.succeeded else {
                throw GitHubCLIError.commandFailed(result.failureMessage)
            }
        } catch let error as CommandError {
            throw Self.mapped(error)
        } catch let error as GitHubCLIError {
            throw error
        } catch {
            throw .commandFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func run(_ arguments: [String]) async throws(GitHubCLIError) -> CommandResult {
        let request = CommandRequest(
            executablePath: gitHubCLIPath,
            arguments: arguments,
            extraEnvironment: ["GH_PROMPT_DISABLED": "1", "NO_COLOR": "1"]
        )

        do {
            return try await commandRunner.run(request)
        } catch {
            throw Self.mapped(error)
        }
    }

    private static func mapped(_ error: CommandError) -> GitHubCLIError {
        switch error {
        case .executableMissing:
            .notInstalled
        case .cancelled:
            .cancelled
        case let .launchFailed(message):
            .commandFailed(message)
        case .outputUnreadable:
            .commandFailed("Unable to read command output")
        }
    }
}
