import SwiftUI

struct GitHubAccountsScreen: View {
    // MARK: - Environment

    @Environment(\.accountsService) private var accounts
    @Environment(\.repositoriesService) private var repositories
    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var isFallbackEnabled = false
    @State private var isAccessCheckEnabled = false

    // MARK: - View

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                content
                fallbackSettings
                associations
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await accounts.start()
        }
        .onChange(of: settings.preferences.accountFallbackEnabled, initial: true) {
            isFallbackEnabled = settings.preferences.accountFallbackEnabled
        }
        .onChange(of: isFallbackEnabled) {
            accounts.setFallbackEnabled(isFallbackEnabled)
        }
        .onChange(of: settings.preferences.accountAccessChecksEnabled, initial: true) {
            isAccessCheckEnabled = settings.preferences.accountAccessChecksEnabled
        }
        .onChange(of: isAccessCheckEnabled) {
            accounts.setAccessChecksEnabled(isAccessCheckEnabled)
        }
    }

    // MARK: - Load state

    @ViewBuilder
    private var content: some View {
        switch accounts.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case let .unavailable(error):
            EmptyStateView(
                symbolName: "person.crop.circle.badge.exclamationmark",
                title: error.message,
                message: String(
                    localized: """
                    Ordinary git sync still works with your existing git authentication. Account \
                    management and retrying a push with another account need gh.
                    """
                ),
                actionTitle: String(localized: "Check again"),
                action: { Task { await accounts.refresh() } }
            )
        case .empty:
            EmptyStateView(
                symbolName: "person.crop.circle",
                title: String(localized: "No accounts signed in"),
                message: String(localized: "Sign in with gh to manage accounts here.")
            )
        case let .loaded(list):
            accountList(list)
        }
    }

    private func accountList(_ list: [GitHubAccount]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(String(localized: "Signed in"))
                .font(.headline)

            ForEach(list) { account in
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: account.isActive ? "checkmark.circle.fill" : "person.crop.circle")
                        .foregroundStyle(account.isActive ? Color.green : Color.secondary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(account.login)
                            .font(.body.weight(.medium))

                        Text(account.host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if accounts.switchingAccount == account.login {
                        ProgressView()
                            .controlSize(.small)
                    } else if account.isActive == false {
                        Button(String(localized: "Make active")) {
                            Task {
                                await accounts.switchTo(account)
                            }
                        }
                    }
                }
                .padding(AppSpacing.medium)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: AppSpacing.small))
            }

            if let failure = accounts.lastSwitchFailure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Settings

    private var fallbackSettings: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(String(localized: "When a push is refused"))
                .font(.headline)

            Toggle(String(localized: "Retry with the other signed-in accounts"), isOn: $isFallbackEnabled)

            Toggle(String(localized: "Check account access before syncing"), isOn: $isAccessCheckEnabled)

            Text(
                String(
                    localized: "dotgit always puts the account that was active back afterwards, whether or not a retry worked."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Associations

    private var associations: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(String(localized: "Preferred account per repository"))
                .font(.headline)

            ForEach(repositories.repositories) { repository in
                RepositoryAccountPicker(
                    repositoryName: repository.name,
                    preferredLogin: repository.shared.preferredGitHubAccount,
                    accounts: accounts.accounts,
                    explanation: accounts.inapplicabilityExplanation(for: repository)
                ) { login in
                    accounts.associate(login, with: repository)
                }
            }
        }
    }
}

#if DEBUG
    #Preview("Signed in") {
        GitHubAccountsScreen()
            .environment(\.accountsService, PreviewGraph.populated.accounts)
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.settingsService, PreviewGraph.populated.settings)
            .frame(width: 720, height: 620)
    }

    #Preview("gh missing") {
        GitHubAccountsScreen()
            .environment(
                \.accountsService,
                PreviewGraph.make(repositories: [], paths: [:], snapshots: [:], gitHubAvailable: false).accounts
            )
            .environment(\.repositoriesService, PreviewGraph.empty.repositories)
            .environment(\.settingsService, PreviewGraph.empty.settings)
            .frame(width: 720, height: 620)
    }

    #Preview("Long names") {
        GitHubAccountsScreen()
            .environment(\.accountsService, PreviewGraph.longNames.accounts)
            .environment(\.repositoriesService, PreviewGraph.longNames.repositories)
            .environment(\.settingsService, PreviewGraph.longNames.settings)
            .frame(width: 720, height: 620)
    }
#endif
