import SwiftUI

struct CheckoutPicker: View {
    // MARK: - Constants

    private enum Constants {
        static let selectedOpacity: Double = 0.18
    }

    // MARK: - Binding

    @Binding var selection: String?

    // MARK: - Inputs

    let repository: TrackedRepository

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(String(localized: "Checkouts"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 0) {
                row(for: repository, isSelected: selectedCheckoutID == repository.id) {
                    Label(String(localized: "Main checkout"), systemImage: "folder")
                }

                ForEach(repository.worktrees) { worktree in
                    row(for: worktree, isSelected: selectedCheckoutID == worktree.id) {
                        WorktreeLabel(name: worktree.worktree?.name ?? worktree.name)
                    }
                }
            }
        }
    }

    // MARK: - Rows

    private func row(
        for checkout: TrackedRepository,
        isSelected: Bool,
        @ViewBuilder title: () -> some View
    ) -> some View {
        Button {
            selection = checkout.isWorktree ? checkout.id : nil
        } label: {
            HStack(spacing: AppSpacing.small) {
                title()
                    .font(.callout.weight(.medium))
                    .layoutPriority(1)

                RepositoryStatusBadge(status: checkout.status)

                Spacer(minLength: AppSpacing.small)

                if let branch = checkout.currentBranchName {
                    Text(branch)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xsmall)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor.opacity(Constants.selectedOpacity) : Color.clear,
                in: RoundedRectangle(cornerRadius: AppSpacing.xsmall)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Helpers

    private var selectedCheckoutID: String {
        WorktreeUseCase.checkout(in: repository, selectedIdentifier: selection).id
    }
}

#if DEBUG
    #Preview("Main selected") {
        @Previewable @State var selection: String?

        CheckoutPicker(selection: $selection, repository: PreviewGraph.repositoryWithWorktrees)
            .padding(AppSpacing.regular)
            .frame(width: 480)
    }

    #Preview("Worktree selected") {
        @Previewable @State var selection: String? = PreviewGraph.repositoryWithWorktrees.worktrees.first?.id

        CheckoutPicker(selection: $selection, repository: PreviewGraph.repositoryWithWorktrees)
            .padding(AppSpacing.regular)
            .frame(width: 480)
    }

    #Preview("Long names") {
        @Previewable @State var selection: String?

        CheckoutPicker(
            selection: $selection,
            repository: PreviewGraph.repositoryWithWorktrees(
                worktrees: [
                    PreviewGraph.worktree(
                        "an-extremely-long-worktree-folder-name-from-an-agent",
                        branch: "feature/NAT-2938-add-viewer-count-live-badge-to-the-player",
                        dirty: true
                    )
                ]
            )
        )
        .padding(AppSpacing.regular)
        .frame(width: 380)
    }
#endif
