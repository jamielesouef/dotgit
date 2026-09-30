import SwiftUI

struct TodayScreen: View {
    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories
    @Environment(\.syncService) private var sync
    @Environment(\.resumeService) private var resume

    // MARK: - State

    @State private var isShowingResume = false

    // MARK: - View

    var body: some View {
        content
            .task {
                await repositories.start()
                await repositories.evaluateReadinessForAll(checksRemoteTags: false)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button(String(localized: "Prepare to resume"), systemImage: "laptopcomputer.and.arrow.down") {
                        resume.prepare()
                        isShowingResume = true
                    }

                    Button(String(localized: "Review and sync all"), systemImage: "icloud.and.arrow.up") {
                        Task {
                            await sync.review(identifiers: nil)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingResume) {
                ResumeSheet()
            }
            .syncFlow()
    }

    // MARK: - Load state

    @ViewBuilder
    private var content: some View {
        switch repositories.loadState {
        case let .loading(progress):
            RepositoryLoadProgressView(progress: progress)
        case let .error(error):
            EmptyStateView(
                symbolName: "exclamationmark.icloud",
                title: String(localized: "The shared workspace could not be read"),
                message: String(describing: error),
                actionTitle: String(localized: "Try again"),
                action: { Task { await repositories.refresh() } }
            )
        case .empty:
            EmptyStateView(
                symbolName: "folder.badge.plus",
                title: String(localized: "Nothing tracked yet"),
                message: String(
                    localized: "Add a repository from the Repositories tab and homerun will keep an eye on it."
                )
            )
        case .loaded:
            dashboard
        }
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                summaryHeader
                group(
                    title: String(localized: "Work only on this Mac"),
                    symbolName: "arrow.up.circle",
                    repositories: summary.unfinishedWork,
                    emptyMessage: String(localized: "Everything is pushed.")
                )
                group(
                    title: String(localized: "Sync problems"),
                    symbolName: "exclamationmark.triangle",
                    repositories: summary.syncProblems,
                    emptyMessage: String(localized: "No repository needs attention.")
                )
                group(
                    title: String(localized: "Ready to resume"),
                    symbolName: "checkmark.seal",
                    repositories: summary.readyToResume,
                    emptyMessage: String(localized: "No project is fully ready yet.")
                )
                group(
                    title: String(localized: "Not cloned on this Mac"),
                    symbolName: "icloud.and.arrow.down",
                    repositories: summary.notClonedHere,
                    emptyMessage: String(localized: "Every repository in the workspace is here.")
                )
            }
            .padding(AppSpacing.large)
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(MenuBarStatusUseCase.status(for: summary).summary)
                .font(.title2.weight(.semibold))

            Text(lastSyncDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func group(
        title: String,
        symbolName: String,
        repositories list: [TrackedRepository],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Label(title, systemImage: symbolName)
                .font(.headline)

            if list.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list) { repository in
                    TodayRepositoryRow(repository: repository, report: repositories.readinessReports[repository.id]) {
                        Task {
                            await sync.review(identifiers: [repository.id])
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var summary: TodaySummary {
        repositories.todaySummary
    }

    private var lastSyncDescription: String {
        guard let date = summary.lastSuccessfulSync else {
            return String(localized: "No successful sync recorded yet.")
        }

        return String(localized: "Last successful sync \(date.formatted(date: .abbreviated, time: .shortened)).")
    }
}

#if DEBUG
    #Preview("Populated") {
        TodayScreen()
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.syncService, PreviewGraph.populated.sync)
            .environment(\.resumeService, PreviewGraph.populated.resume)
            .frame(width: 760, height: 620)
    }

    #Preview("Empty") {
        TodayScreen()
            .environment(\.repositoriesService, PreviewGraph.empty.repositories)
            .environment(\.syncService, PreviewGraph.empty.sync)
            .environment(\.resumeService, PreviewGraph.empty.resume)
            .frame(width: 760, height: 620)
    }

    #Preview("Long names") {
        TodayScreen()
            .environment(\.repositoriesService, PreviewGraph.longNames.repositories)
            .environment(\.syncService, PreviewGraph.longNames.sync)
            .environment(\.resumeService, PreviewGraph.longNames.resume)
            .frame(width: 760, height: 620)
    }
#endif
