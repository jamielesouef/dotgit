import SwiftUI

struct StartupChecklist: View {
    // MARK: - Constants

    private enum Constants {
        static let iconWidth: CGFloat = 16
    }

    // MARK: - Inputs

    let steps: [StartupStep]

    // MARK: - View

    var body: some View {
        Grid(
            alignment: .leadingFirstTextBaseline,
            horizontalSpacing: AppSpacing.small,
            verticalSpacing: AppSpacing.small
        ) {
            ForEach(steps) { step in
                GridRow {
                    icon(for: step.status)
                        .frame(width: Constants.iconWidth)

                    Text(step.check.title)
                        .fontWeight(.medium)
                        .foregroundStyle(step.status == .waiting ? .secondary : .primary)

                    Text(step.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.callout)
        .animation(.snappy, value: steps)
    }

    // MARK: - Icon

    @ViewBuilder
    private func icon(for status: StartupStepStatus) -> some View {
        switch status {
        case .waiting:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .running:
            SnakeProgressView()
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .warning:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
    #Preview("Waiting") {
        StartupChecklist(steps: StartupProgressUseCase.waitingSteps())
            .padding(AppSpacing.regular)
    }

    #Preview("Part way") {
        StartupChecklist(
            steps: [
                StartupProgressUseCase.gitChecked(isAvailable: true),
                StartupProgressUseCase.gitHubCLIChecked(isAvailable: true),
                StartupProgressUseCase.running(.gitHubAccounts)
            ]
        )
        .padding(AppSpacing.regular)
    }

    #Preview("Missing tools") {
        StartupChecklist(
            steps: [
                StartupProgressUseCase.gitChecked(isAvailable: false),
                StartupProgressUseCase.gitHubCLIChecked(isAvailable: false),
                StartupProgressUseCase.gitHubAccountsChecked(isGitHubCLIAvailable: false, accounts: [])
            ]
        )
        .padding(AppSpacing.regular)
    }

    #Preview("Many accounts") {
        StartupChecklist(
            steps: [
                StartupProgressUseCase.gitChecked(isAvailable: true),
                StartupProgressUseCase.gitHubCLIChecked(isAvailable: true),
                StartupProgressUseCase.gitHubAccountsChecked(
                    isGitHubCLIAvailable: true,
                    accounts: [
                        GitHubAccount(login: "a-very-long-github-login-name", host: "github.com", isActive: true),
                        GitHubAccount(login: "work-account", host: "github.com", isActive: false),
                        GitHubAccount(login: "enterprise-user", host: "github.example.com", isActive: false)
                    ]
                )
            ]
        )
        .frame(width: 380)
        .padding(AppSpacing.regular)
    }
#endif
