import SwiftUI

struct EmptyStateView: View {
    // MARK: - Inputs

    let symbolName: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    // MARK: - View

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: symbolName)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xlarge)
    }
}

#if DEBUG
    #Preview("Message only") {
        EmptyStateView(
            symbolName: "folder",
            title: String(localized: "No repositories yet"),
            message: String(localized: "Add a folder to start tracking it.")
        )
        .frame(width: 520, height: 320)
    }

    #Preview("With an action and long text") {
        EmptyStateView(
            symbolName: "exclamationmark.triangle",
            title: String(localized: "The shared workspace could not be read"),
            message: String(
                localized: """
                dotgit could not reach the shared workspace on this Mac. Your repositories and their \
                files are untouched; only the list dotgit keeps is unavailable right now.
                """
            ),
            actionTitle: String(localized: "Try again"),
            action: {}
        )
        .frame(width: 520, height: 320)
    }
#endif
