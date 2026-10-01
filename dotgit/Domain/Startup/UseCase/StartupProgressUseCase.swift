import Foundation

enum StartupProgressUseCase {
    // MARK: - Steps

    static func waitingSteps() -> [StartupStep] {
        StartupCheck.allCases.map { check in
            StartupStep(check: check, status: .waiting, detail: String(localized: "Waiting"))
        }
    }

    static func running(_ check: StartupCheck) -> StartupStep {
        switch check {
        case .git,
             .gitHubCLI:
            StartupStep(check: check, status: .running, detail: String(localized: "Looking on this Mac"))
        case .gitHubAccounts:
            StartupStep(check: check, status: .running, detail: String(localized: "Confirming with GitHub"))
        }
    }

    static func gitChecked(isAvailable: Bool) -> StartupStep {
        guard isAvailable else {
            return StartupStep(
                check: .git,
                status: .failed,
                detail: String(localized: "Not found, and dotgit needs it")
            )
        }

        return StartupStep(check: .git, status: .passed, detail: String(localized: "Found"))
    }

    static func gitHubCLIChecked(isAvailable: Bool) -> StartupStep {
        guard isAvailable else {
            return StartupStep(
                check: .gitHubCLI,
                status: .warning,
                detail: String(localized: "Not installed, optional")
            )
        }

        return StartupStep(check: .gitHubCLI, status: .passed, detail: String(localized: "Found"))
    }

    static func gitHubAccountsChecked(isGitHubCLIAvailable: Bool, accounts: [GitHubAccount]) -> StartupStep {
        switch (isGitHubCLIAvailable, accounts.isEmpty) {
        case (false, _):
            StartupStep(
                check: .gitHubAccounts,
                status: .skipped,
                detail: String(localized: "Skipped, needs the GitHub CLI")
            )
        case (true, true):
            StartupStep(check: .gitHubAccounts, status: .warning, detail: String(localized: "No account signed in"))
        case (true, false):
            StartupStep(check: .gitHubAccounts, status: .passed, detail: signedInDetail(accounts))
        }
    }

    // MARK: - Updating

    static func replacing(_ step: StartupStep, in steps: [StartupStep]) -> [StartupStep] {
        steps.map { $0.check == step.check ? step : $0 }
    }

    // MARK: - Helpers

    private static func signedInDetail(_ accounts: [GitHubAccount]) -> String {
        let logins = accounts
            .map { account in
                account.isActive ? String(localized: "\(account.login) (active)") : account.login
            }
            .formatted(.list(type: .and))

        return String(localized: "Signed in as \(logins)")
    }
}
