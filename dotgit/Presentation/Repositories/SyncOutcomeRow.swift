import SwiftUI

struct SyncOutcomeRow: View {
    // MARK: - Inputs

    let outcome: RepositorySyncOutcome

    // MARK: - View

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(outcome.identifier)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private var symbolName: String {
        switch outcome.result {
        case .succeeded:
            "checkmark.circle.fill"
        case .skipped:
            "minus.circle"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch outcome.result {
        case .succeeded:
            .green
        case .skipped:
            .secondary
        case .failed:
            .red
        }
    }

    private var detail: String {
        switch outcome.result {
        case let .succeeded(commit, branch):
            String(localized: "Pushed \(branch ?? "the current branch") at \(commit?.prefix(7).description ?? "HEAD")")
        case let .skipped(reason):
            reason
        case let .failed(failure):
            failure.message
        }
    }
}

#if DEBUG
    #Preview("Each result") {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            SyncOutcomeRow(
                outcome: RepositorySyncOutcome(
                    identifier: "remote:github.com/acme/app",
                    result: .succeeded(commit: "abc1234def", branch: "feature/login"),
                    finishedAt: .now
                )
            )
            SyncOutcomeRow(
                outcome: RepositorySyncOutcome(
                    identifier: "remote:github.com/acme/tooling",
                    result: .skipped("Already up to date"),
                    finishedAt: .now
                )
            )
            SyncOutcomeRow(
                outcome: RepositorySyncOutcome(
                    identifier: "remote:github.com/acme/archive",
                    result: .failed(.authentication("remote: Authentication failed for the repository")),
                    finishedAt: .now
                )
            )
        }
        .padding()
        .frame(width: 440)
    }
#endif
