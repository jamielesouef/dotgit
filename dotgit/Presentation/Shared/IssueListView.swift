import SwiftUI

struct IssueListView: View {
    // MARK: - Inputs

    let issues: [ReadinessIssue]

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ForEach(issues) { issue in
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    Label(issue.title, systemImage: "exclamationmark.circle")
                        .font(.callout.weight(.medium))

                    Text(issue.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#if DEBUG
    #Preview("No issues") {
        IssueListView(issues: [])
            .padding(AppSpacing.regular)
            .frame(width: 420)
    }

    #Preview("Several issues with long explanations") {
        IssueListView(issues: [
            .untrackedFiles(["Notes.md", "Scratch/ideas-about-the-new-thing.md"]),
            .localOnlyBranches(["spike", "experiment/try-the-other-approach"]),
            .requiredEnvironmentVariables(["API_HOST", "API_TOKEN"]),
            .missingSetupInstructions
        ])
        .padding(AppSpacing.regular)
        .frame(width: 420)
    }
#endif
