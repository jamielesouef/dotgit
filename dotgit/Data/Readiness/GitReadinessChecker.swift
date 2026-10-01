import Foundation

struct GitReadinessChecker: @unchecked Sendable, ReadinessChecking {
    // MARK: - Private

    private let gitClient: any GitClienting
    private let fileManager: FileManager

    // MARK: - Init

    init(gitClient: any GitClienting, fileManager: FileManager) {
        self.gitClient = gitClient
        self.fileManager = fileManager
    }

    // MARK: - ReadinessChecking

    func evaluate(_ input: ReadinessCheckInput) async -> ReadinessReport {
        await ReadinessEvaluationUseCase.report(
            identifier: input.repository.identifier,
            snapshot: input.snapshot,
            repository: input.repository,
            signals: ReadinessCheckSignals(
                unpushedTags: unpushedTags(input),
                missingConfigurationTemplates: missingTemplates(input),
                hasSetupInstructions: hasSetupInstructions(input)
            )
        )
    }

    // MARK: - Helpers

    private func unpushedTags(_ input: ReadinessCheckInput) async -> [String] {
        guard input.checksRemoteTags, let remote = input.snapshot.defaultRemoteName else {
            return []
        }
        guard let local = try? await gitClient.localTags(at: input.directory),
              local.isEmpty == false,
              let remoteTags = try? await gitClient.remoteTags(remote: remote, at: input.directory)
        else {
            return []
        }

        return GitRemoteTagParser.unpushedTags(local: local, remote: remoteTags)
    }

    private func missingTemplates(_ input: ReadinessCheckInput) -> [String] {
        input.repository.expectedConfigurationTemplates.filter { relativePath in
            exists(relativePath, in: input.directory) == false
        }
    }

    private func hasSetupInstructions(_ input: ReadinessCheckInput) -> Bool {
        guard let path = input.repository.setupInstructionsPath, path.isEmpty == false else {
            return false
        }

        return exists(path, in: input.directory)
    }

    private func exists(_ relativePath: String, in directory: URL) -> Bool {
        fileManager.fileExists(atPath: directory.appending(path: relativePath).path(percentEncoded: false))
    }
}
