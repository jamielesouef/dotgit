import SwiftUI

struct ResumeSheet: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 620
        static let height: CGFloat = 520
    }

    // MARK: - Environment

    @Environment(\.resumeService) private var resume
    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            content
        }
        .padding(AppSpacing.large)
        .frame(width: Constants.width, height: Constants.height)
        .task {
            guard resume.reviewPlan == nil else {
                return
            }

            resume.prepare()
        }
    }

    // MARK: - Phase

    @ViewBuilder
    private var content: some View {
        switch resume.phase {
        case .idle:
            ProgressView()
        case let .reviewing(plan):
            review(plan)
        case let .running(progress):
            running(progress)
        case let .finished(summary):
            finished(summary)
        }
    }

    private func review(_ plan: ResumePlan) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(String(localized: "Prepare this Mac"))
                    .font(.title2.weight(.semibold))

                Text(
                    String(
                        localized: "dotgit will clone what is missing and fast-forward what is safe. Nothing is merged or rebased."
                    )
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    ForEach(plan.steps) { step in
                        ResumeStepRow(step: step) { isSelected in
                            resume.setSelection(isSelected, for: step.identifier)
                        }
                    }
                }
            }

            HStack {
                Spacer()

                Button(String(localized: "Cancel")) {
                    resume.cancelReview()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "Prepare")) {
                    Task {
                        await resume.run()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(plan.isEmpty)
            }
        }
    }

    private func running(_ progress: SyncProgress) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text(String(localized: "Preparing"))
                .font(.title2.weight(.semibold))

            ProgressView(value: progress.fraction)

            Text(progress.currentRepositoryName ?? String(localized: "Finishing up"))
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func finished(_ summary: ResumeSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text(String(localized: "This Mac is prepared"))
                .font(.title2.weight(.semibold))

            Text(String(localized: "\(summary.succeededCount) ready, \(summary.failedCount) need attention."))
                .font(.callout)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    ForEach(summary.outcomes) { outcome in
                        HStack(alignment: .top, spacing: AppSpacing.small) {
                            Image(systemName: outcome
                                .succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(outcome.succeeded ? Color.green : Color.red)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                                Text(outcome.name)
                                    .font(.callout.weight(.medium))

                                if let failureMessage = outcome.failureMessage {
                                    Text(failureMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer(minLength: AppSpacing.small)

                            if resume.offersToOpenProjects, outcome.succeeded, outcome.openableURL != nil {
                                Button(String(localized: "Open")) {
                                    Task {
                                        _ = await resume.open(outcome)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()

                Button(String(localized: "Done")) {
                    resume.dismissSummary()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

#if DEBUG
    #Preview("Review") {
        ResumeSheet()
            .environment(\.resumeService, PreviewGraph.populated.resume)
    }

    #Preview("Nothing to prepare") {
        ResumeSheet()
            .environment(\.resumeService, PreviewGraph.empty.resume)
    }
#endif
