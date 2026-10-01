import Foundation

struct GitHubAccountPushFallback: PushFallbackPerforming {
    // MARK: - Private

    private let gitClient: any GitClienting
    private let gitHubClient: any GitHubCLIClienting

    // MARK: - Init

    init(gitClient: any GitClienting, gitHubClient: any GitHubCLIClienting) {
        self.gitClient = gitClient
        self.gitHubClient = gitHubClient
    }

    // MARK: - PushFallbackPerforming

    func retryPush(_ context: PushAttemptContext) async -> AccountFallbackResult {
        guard AccountFallbackUseCase.appliesToRemote(context.remoteURL) else {
            return .notApplicable(AccountFallbackUseCase.inapplicableExplanation(for: context.remoteURL))
        }
        guard await gitHubClient.isAvailable() else {
            return .notApplicable(GitHubCLIError.notInstalled.message)
        }
        guard let accounts = try? await gitHubClient.accounts(), accounts.isEmpty == false else {
            return .notApplicable(GitHubCLIError.notAuthenticated.message)
        }

        let originalAccount = AccountFallbackUseCase.accountToRestore(from: accounts)
        let candidates = AccountFallbackUseCase.candidates(
            from: accounts,
            preferred: context.preferredAccount,
            excluding: originalAccount
        )

        guard candidates.isEmpty == false else {
            await restore(originalAccount, accounts: accounts)
            return .exhausted([])
        }

        let result = await attempt(candidates, context: context, accounts: accounts)
        await restore(originalAccount, accounts: accounts)

        return result
    }

    // MARK: - Helpers

    private func attempt(
        _ candidates: [String],
        context: PushAttemptContext,
        accounts: [GitHubAccount]
    ) async -> AccountFallbackResult {
        var attempts: [AccountFallbackAttempt] = []

        for candidate in candidates {
            let host = accounts.first { $0.login == candidate }?.host ?? "github.com"

            do {
                try await gitHubClient.switchAccount(to: candidate, host: host)
            } catch {
                attempts.append(AccountFallbackAttempt(account: candidate, failureMessage: error.message))
                continue
            }

            do {
                try await gitClient.push(
                    branch: context.branch,
                    remote: context.remote,
                    setUpstream: context.setsUpstream,
                    at: context.directory
                )
            } catch {
                attempts.append(AccountFallbackAttempt(account: candidate, failureMessage: String(describing: error)))
                continue
            }

            attempts.append(AccountFallbackAttempt(account: candidate, failureMessage: nil))

            return .succeeded(account: candidate, attempts: attempts)
        }

        return .exhausted(attempts)
    }

    private func restore(_ login: String?, accounts: [GitHubAccount]) async {
        guard let login else {
            return
        }

        let host = accounts.first { $0.login == login }?.host ?? "github.com"

        do {
            try await gitHubClient.switchAccount(to: login, host: host)
        } catch {
            AppLog.error("Could not restore the GitHub account \(login): \(error.message)")
        }
    }
}
