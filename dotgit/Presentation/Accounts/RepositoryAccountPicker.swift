import SwiftUI

struct RepositoryAccountPicker: View {
    // MARK: - State

    @State private var selection: String?

    // MARK: - Inputs

    let repositoryName: String
    let preferredLogin: String?
    let accounts: [GitHubAccount]
    let explanation: String?
    let onPreferredLoginChange: (String?) -> Void

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Picker(repositoryName, selection: $selection) {
                Text(String(localized: "No preference")).tag(String?.none)

                ForEach(accounts) { account in
                    Text(account.login).tag(String?.some(account.login))
                }
            }

            if let explanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: preferredLogin, initial: true) {
            selection = preferredLogin
        }
        .onChange(of: selection) {
            onPreferredLoginChange(selection)
        }
    }
}

#if DEBUG
    #Preview("Chosen account") {
        @Previewable @State var preferredLogin: String? = "acme-bot"

        RepositoryAccountPicker(
            repositoryName: "dotgit",
            preferredLogin: preferredLogin,
            accounts: [
                GitHubAccount(login: "jamie", host: "github.com", isActive: true),
                GitHubAccount(login: "acme-bot", host: "github.com", isActive: false)
            ],
            explanation: nil,
            onPreferredLoginChange: { preferredLogin = $0 }
        )
        .padding(AppSpacing.large)
        .frame(width: 480)
    }

    #Preview("Long name, SSH remote") {
        @Previewable @State var preferredLogin: String?

        RepositoryAccountPicker(
            repositoryName: "an-extremely-long-repository-name-from-a-monorepo-migration-that-never-ended",
            preferredLogin: preferredLogin,
            accounts: [GitHubAccount(login: "jamie-with-a-long-enterprise-login", host: "github.com", isActive: true)],
            explanation: "Account switching only applies to HTTPS remotes. This repository pushes over SSH, " +
                "so git uses your SSH key whichever account is active.",
            onPreferredLoginChange: { preferredLogin = $0 }
        )
        .padding(AppSpacing.large)
        .frame(width: 480)
    }

    #Preview("No accounts signed in") {
        RepositoryAccountPicker(
            repositoryName: "dotgit",
            preferredLogin: "someone-signed-out",
            accounts: [],
            explanation: nil,
            onPreferredLoginChange: { _ in }
        )
        .padding(AppSpacing.large)
        .frame(width: 480)
    }
#endif
