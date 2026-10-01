import SwiftUI

struct WorktreeLabel: View {
    // MARK: - Constants

    private enum Constants {
        static let symbolName = "tree"
    }

    // MARK: - Inputs

    let name: String

    // MARK: - View

    var body: some View {
        Label(name, systemImage: Constants.symbolName)
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityLabel(String(localized: "Worktree \(name)"))
    }
}

#if DEBUG
    #Preview("Short and long") {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            WorktreeLabel(name: "hotfix")

            WorktreeLabel(name: "feature+a-very-long-worktree-name-that-will-not-fit-anywhere-sensible")
                .frame(width: 220, alignment: .leading)
        }
        .padding(AppSpacing.regular)
    }
#endif
