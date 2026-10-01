import SwiftUI

struct MenuBarContentView: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 300
        static let failureLimit = 3
    }

    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories
    @Environment(\.syncService) private var sync
    @Environment(\.resumeService) private var resume
    @Environment(\.openWindow) private var openWindow

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            status
            Divider()
            counts
            failures
            Divider()
            actions
        }
        .padding(AppSpacing.medium)
        .frame(width: Constants.width)
        .task {
            await repositories.start()
        }
    }

    // MARK: - Status

    private var status: some View {
        Label(currentStatus.summary, systemImage: currentStatus.level.symbolName)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var counts: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(String(localized: "\(currentStatus.localOnlyCount) with work only on this Mac"))
                .font(.callout)

            Text(lastSyncDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var failures: some View {
        let problems = repositories.todaySummary.syncProblems

        if problems.isEmpty == false {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(String(localized: "Needs attention"))
                    .font(.caption.weight(.semibold))

                ForEach(problems.prefix(Constants.failureLimit)) { repository in
                    Label(repository.name, systemImage: repository.status.symbolName)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Button(String(localized: "Review and sync all")) {
                openWindow(id: AppWindow.main.rawValue)

                Task {
                    await sync.review(identifiers: nil)
                }
            }

            Button(String(localized: "Prepare to resume")) {
                openWindow(id: AppWindow.main.rawValue)
                resume.prepare()
            }

            Button(String(localized: "Open dotgit")) {
                openWindow(id: AppWindow.main.rawValue)
            }

            Divider()

            Button(String(localized: "Quit dotgit")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var currentStatus: MenuBarStatus {
        MenuBarStatusUseCase.status(for: repositories.todaySummary)
    }

    private var lastSyncDescription: String {
        guard let date = repositories.todaySummary.lastSuccessfulSync else {
            return String(localized: "No successful sync recorded yet")
        }

        return String(localized: "Last synced \(date.formatted(date: .abbreviated, time: .shortened))")
    }
}

#if DEBUG
    #Preview("Work outstanding") {
        MenuBarContentView()
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.syncService, PreviewGraph.populated.sync)
            .environment(\.resumeService, PreviewGraph.populated.resume)
    }

    #Preview("Nothing tracked") {
        MenuBarContentView()
            .environment(\.repositoriesService, PreviewGraph.empty.repositories)
            .environment(\.syncService, PreviewGraph.empty.sync)
            .environment(\.resumeService, PreviewGraph.empty.resume)
    }
#endif
