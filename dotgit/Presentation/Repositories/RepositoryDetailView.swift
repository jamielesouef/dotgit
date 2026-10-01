import SwiftUI

struct RepositoryDetailView: View {
    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories
    @Environment(\.accountsService) private var accounts
    @Environment(\.settingsService) private var settings
    @Environment(\.syncService) private var sync

    // MARK: - State

    @State private var commits: [GitCommitSummary] = []
    @State private var diff = ""
    @State private var appendsTimestamp = true
    @State private var wipCommitPrefix = ""
    @State private var preferredAccount: String?
    @State private var selectedCheckoutID: String?

    // MARK: - Inputs

    let repository: TrackedRepository

    // MARK: - View

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                header
                configuration
                changes
                readiness
                activity
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: checkout.id) {
            let checkout = checkout
            commits = await repositories.recentCommits(for: checkout, limit: AppConstants.recentCommitLimit)
            diff = await repositories.diffSummary(for: checkout)
            await repositories.evaluateReadiness(for: checkout, checksRemoteTags: false)
        }
        .onChange(of: repository.id) {
            selectedCheckoutID = nil
        }
        .task {
            await accounts.start()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(repository.name)
                .font(.largeTitle.weight(.semibold))
                .lineLimit(2)

            if repository.worktrees.isEmpty == false {
                CheckoutPicker(selection: $selectedCheckoutID, repository: repository)
                    .padding(.vertical, AppSpacing.small)
            }

            RepositoryStatusBadge(status: checkout.status)

            Text(checkout.localPath?.path(percentEncoded: false) ?? String(localized: "Not cloned on this Mac"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let remote = checkout.snapshot?.remoteURL ?? repository.shared.remoteURL {
                Text(remote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            syncButtons
                .padding(.top, AppSpacing.small)
        }
    }

    private var syncButtons: some View {
        HStack(spacing: AppSpacing.small) {
            Button(WorktreeUseCase.syncTitle(for: checkout, in: repository)) {
                Task {
                    await sync.review(identifiers: [checkout.id], includesWorktrees: false)
                }
            }
            .disabled(checkout.isCloned == false)

            if repository.worktrees.isEmpty == false {
                Button(String(localized: "Sync with all worktrees")) {
                    Task {
                        await sync.review(identifiers: [repository.id], includesWorktrees: true)
                    }
                }
                .disabled(repository.isCloned == false)
            }
        }
    }

    // MARK: - Configuration

    private var configuration: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(String(localized: "This repository"))
                .font(.headline)

            ForEach(BranchSyncPolicyUseCase.protectedBranchesPresent(in: repository.snapshot), id: \.self) { branch in
                BranchSyncToggle(
                    branch: branch,
                    isAllowed: BranchSyncPolicyUseCase.isSyncAllowed(branch: branch, in: repository.shared)
                ) { isAllowed in
                    setSyncAllowed(isAllowed, branch: branch)
                }
            }

            LabeledContent(String(localized: "WIP commit prefix")) {
                TextField(
                    AppPreferences.fallbackWIPCommitPrefix,
                    text: $wipCommitPrefix
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            }

            Toggle(String(localized: "Append the time to the commit message"), isOn: $appendsTimestamp)
                .disabled(settings.preferences.appendsTimestampToWIPCommit == false)

            if settings.preferences.appendsTimestampToWIPCommit == false {
                Text(String(localized: "Timestamps are turned off for every repository in Settings."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker(String(localized: "Preferred GitHub account"), selection: $preferredAccount) {
                Text(String(localized: "No preference")).tag(String?.none)

                ForEach(accounts.accounts) { account in
                    Text(account.login).tag(String?.some(account.login))
                }
            }

            if let explanation = accounts.inapplicabilityExplanation(for: repository) {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: repository.shared.omitsTimestampFromWIPCommit, initial: true) {
            appendsTimestamp = repository.shared.omitsTimestampFromWIPCommit == false
        }
        .onChange(of: appendsTimestamp) {
            setAppendsTimestamp(appendsTimestamp)
        }
        .onChange(of: repository.shared.wipCommitPrefixOverride, initial: true) {
            wipCommitPrefix = repository.shared.wipCommitPrefixOverride ?? ""
        }
        .onChange(of: wipCommitPrefix) {
            setWIPCommitPrefix(wipCommitPrefix)
        }
        .onChange(of: repository.shared.preferredGitHubAccount, initial: true) {
            preferredAccount = repository.shared.preferredGitHubAccount
        }
        .onChange(of: preferredAccount) {
            accounts.associate(preferredAccount, with: repository)
        }
    }

    // MARK: - Changes

    @ViewBuilder
    private var changes: some View {
        if let snapshot = checkout.snapshot {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(String(localized: "Changes"))
                    .font(.headline)

                if snapshot.workingTree.isClean {
                    Text(String(localized: "The working tree is clean."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.workingTree.trackedChanges) { change in
                        Label("\(change.status.rawValue): \(change.path)", systemImage: "doc.text")
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    ForEach(snapshot.workingTree.untrackedPaths, id: \.self) { path in
                        Label(path, systemImage: "doc.badge.plus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if diff.isEmpty == false {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(AppSpacing.small)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: AppSpacing.xsmall))
                }
            }
        }
    }

    // MARK: - Readiness

    @ViewBuilder
    private var readiness: some View {
        if let report = repositories.readinessReports[checkout.id] {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(String(localized: "Ready to resume elsewhere"))
                    .font(.headline)

                Label(
                    report.currentBranchPushed
                        ? String(localized: "The current branch is pushed")
                        : String(localized: "The current branch is not pushed"),
                    systemImage: report.currentBranchPushed ? "checkmark.circle" : "xmark.circle"
                )
                .font(.callout)

                if report.isReadyToResume {
                    Label(
                        String(localized: "Nothing would stop this continuing on another Mac."),
                        systemImage: "checkmark.seal"
                    )
                    .font(.callout)
                    .foregroundStyle(.green)
                } else {
                    IssueListView(issues: report.issues)
                }
            }
        }
    }

    // MARK: - Activity

    @ViewBuilder
    private var activity: some View {
        if commits.isEmpty == false {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(String(localized: "Recent activity"))
                    .font(.headline)

                ForEach(commits) { commit in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(commit.subject)
                            .font(.callout)
                            .lineLimit(2)

                        Text(
                            "\(commit.shortHash) · \(commit.authorName) · \(commit.date.formatted(date: .abbreviated, time: .shortened))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var checkout: TrackedRepository {
        WorktreeUseCase.checkout(in: repository, selectedIdentifier: selectedCheckoutID)
    }

    private func setAppendsTimestamp(_ appendsTimestamp: Bool) {
        var shared = repository.shared
        shared.omitsTimestampFromWIPCommit = appendsTimestamp == false
        repositories.update(shared)
    }

    private func setSyncAllowed(_ isAllowed: Bool, branch: String) {
        var shared = repository.shared
        BranchSyncPolicyUseCase.setSyncAllowed(isAllowed, branch: branch, in: &shared)
        repositories.update(shared)
    }

    private func setWIPCommitPrefix(_ prefix: String) {
        var shared = repository.shared
        shared.wipCommitPrefixOverride = prefix.isEmpty ? nil : prefix
        repositories.update(shared)
    }
}

#if DEBUG
    #Preview("Dirty repository") {
        RepositoryDetailView(
            repository: TrackedRepository(
                shared: PreviewGraph.sampleRepositories[0],
                localPath: URL(filePath: "/Users/preview/Developer/app"),
                snapshot: PreviewGraph.snapshot(
                    branch: "feature/login",
                    ahead: 3,
                    tracked: [GitFileChange(path: "Sources/Login.swift", status: .modified)],
                    untracked: ["Notes.md"]
                )
            )
        )
        .environment(\.repositoriesService, PreviewGraph.populated.repositories)
        .environment(\.accountsService, PreviewGraph.populated.accounts)
        .frame(width: 620, height: 640)
    }

    #Preview("With worktrees") {
        RepositoryDetailView(repository: PreviewGraph.repositoryWithWorktrees)
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.accountsService, PreviewGraph.populated.accounts)
            .environment(\.syncService, PreviewGraph.populated.sync)
            .frame(width: 620, height: 720)
    }

    #Preview("Not cloned") {
        RepositoryDetailView(repository: TrackedRepository(shared: PreviewGraph.sampleRepositories[2]))
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.accountsService, PreviewGraph.populated.accounts)
            .frame(width: 620, height: 640)
    }

    #Preview("Long names") {
        RepositoryDetailView(
            repository: TrackedRepository(
                shared: WorkspaceRepository(
                    identifier: "x",
                    name: "an-extremely-long-repository-name-that-wraps-onto-several-lines",
                    remoteURL: "https://github.com/acme/an-extremely-long-repository-name-that-wraps.git"
                ),
                localPath: URL(filePath: "/Users/preview/Developer/clients/acme/a/deeply/nested/place"),
                snapshot: PreviewGraph.snapshot(branch: "feature/a-very-long-branch-name-for-a-very-long-piece-of-work")
            )
        )
        .environment(\.repositoriesService, PreviewGraph.longNames.repositories)
        .environment(\.accountsService, PreviewGraph.longNames.accounts)
        .frame(width: 620, height: 640)
    }
#endif
