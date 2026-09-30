import SwiftUI

struct SyncReviewSheet: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 620
        static let height: CGFloat = 520
    }

    // MARK: - Environment

    @Environment(\.syncService) private var sync
    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var requiresSyncConfirmation = AppPreferences.default.requiresSyncConfirmation
    @State private var isConfirmingUpstreams = false

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            header
            Divider()
            steps
            Divider()
            footer
        }
        .padding(AppSpacing.large)
        .frame(width: Constants.width, height: Constants.height)
        .onChange(of: settings.preferences.requiresSyncConfirmation, initial: true) {
            requiresSyncConfirmation = settings.preferences.requiresSyncConfirmation
        }
        .onChange(of: requiresSyncConfirmation) {
            settings.updatePreferences { $0.requiresSyncConfirmation = requiresSyncConfirmation }
        }
        // A task rather than `onChange(initial:)`, so the dialog waits for the sheet
        // to appear when confirmation is off and the review opens straight into it.
        .task(id: sync.phase) {
            isConfirmingUpstreams = sync.upstreamConfirmationPlan != nil
        }
        .confirmationDialog(
            String(localized: "Create these branches on the remote?"),
            isPresented: $isConfirmingUpstreams
        ) {
            upstreamActions
        } message: {
            Text((sync.upstreamConfirmationPlan?.newUpstreamBranches ?? []).joined(separator: "\n"))
        }
    }

    // MARK: - Upstream confirmation

    @ViewBuilder
    private var upstreamActions: some View {
        Button(String(localized: "Create and Push")) {
            Task {
                await sync.confirmUpstreams(creates: true)
            }
        }

        Button(String(localized: "Push Without Creating")) {
            Task {
                await sync.confirmUpstreams(creates: false)
            }
        }

        Button(String(localized: "Cancel"), role: .cancel) {
            sync.cancelUpstreamConfirmation()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(String(localized: "Review the sync"))
                    .font(.title2.weight(.semibold))

                Text(String(localized: "Nothing is committed or pushed until you confirm."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.small)

            if let plan = sync.reviewPlan, plan.hasUntrackedFiles {
                Button(UntrackedSelectionUseCase.selectAllTitle(isEverythingSelected: plan.includesAllUntracked)) {
                    sync.setAllUntracked(isSelected: plan.includesAllUntracked == false)
                }
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var steps: some View {
        if let plan = sync.reviewPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.regular) {
                    ForEach(plan.steps) { step in
                        SyncPlanStepView(step: step) { path, isSelected in
                            sync.setUntracked(path, isSelected: isSelected, for: step.identifier)
                        } onSelectAllUntracked: { isSelected in
                            sync.setAllUntracked(isSelected: isSelected, for: step.identifier)
                        }
                    }
                }
            }
        } else {
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Toggle(String(localized: "Ask me every time"), isOn: $requiresSyncConfirmation)
                .toggleStyle(.checkbox)

            Spacer()

            Button(String(localized: "Cancel")) {
                sync.cancelReview()
            }
            .keyboardShortcut(.cancelAction)

            Button(String(localized: "Sync")) {
                // If the upstream dialog was dismissed without an answer, show it again.
                guard sync.upstreamConfirmationPlan == nil else {
                    isConfirmingUpstreams = true
                    return
                }

                Task {
                    await sync.run()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(sync.reviewPlan?.isEmpty != false)
        }
    }
}

#if DEBUG
    #Preview("Review") {
        SyncReviewSheet()
            .environment(\.syncService, PreviewGraph.populated.sync)
            .environment(\.settingsService, PreviewGraph.populated.settings)
    }

    #Preview("Nothing to do") {
        SyncReviewSheet()
            .environment(\.syncService, PreviewGraph.empty.sync)
            .environment(\.settingsService, PreviewGraph.empty.settings)
    }
#endif
