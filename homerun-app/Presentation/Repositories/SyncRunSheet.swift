import SwiftUI

struct SyncRunSheet: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 520
        static let height: CGFloat = 420
    }

    // MARK: - Environment

    @Environment(\.syncService) private var sync

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            content
        }
        .padding(AppSpacing.large)
        .frame(width: Constants.width, height: Constants.height)
    }

    // MARK: - Phase

    @ViewBuilder
    private var content: some View {
        switch sync.phase {
        case .idle,
             .reviewing,
             .confirmingUpstreams:
            ProgressView()
        case let .running(progress):
            running(progress)
        case let .finished(summary):
            finished(summary)
        }
    }

    private func running(_ progress: SyncProgress) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text(String(localized: "Syncing"))
                .font(.title2.weight(.semibold))

            ProgressView(value: progress.fraction)

            Text(progress.currentRepositoryName ?? String(localized: "Finishing up"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(String(localized: "\(progress.completed) of \(progress.total)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()

                Button(String(localized: "Stop")) {
                    sync.cancelRun()
                }
            }
        }
    }

    private func finished(_ summary: SyncSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text(String(localized: "Sync finished"))
                .font(.title2.weight(.semibold))

            Text(
                String(
                    localized: "\(summary.succeededCount) succeeded, \(summary.skippedCount) skipped, \(summary.failedCount) failed."
                )
            )
            .font(.callout)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    ForEach(summary.outcomes) { outcome in
                        SyncOutcomeRow(outcome: outcome)
                    }
                }
            }

            HStack {
                Spacer()

                Button(String(localized: "Done")) {
                    sync.dismissSummary()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

#if DEBUG
    #Preview("Running") {
        SyncRunSheet()
            .environment(\.syncService, PreviewGraph.populated.sync)
    }
#endif
