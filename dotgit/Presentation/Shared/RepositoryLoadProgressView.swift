import SwiftUI

struct RepositoryLoadProgressView: View {
    // MARK: - Constants

    private enum Constants {
        static let barWidth: CGFloat = 280
    }

    // MARK: - Inputs

    let progress: RepositoryLoadProgress

    // MARK: - View

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            bar
                .frame(width: Constants.barWidth)

            Text(progress.title)
                .font(.callout)
                .monospacedDigit()

            if let detail = progress.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Constants.barWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bar

    @ViewBuilder
    private var bar: some View {
        if let fraction = progress.fractionCompleted {
            ProgressView(value: fraction)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
        }
    }
}

#if DEBUG
    #Preview("Opening") {
        RepositoryLoadProgressView(progress: .opening)
            .frame(width: 500, height: 300)
    }

    #Preview("Part way") {
        RepositoryLoadProgressView(
            progress: RepositoryLoadProgress(total: 12, completed: 5, reading: ["dotgit", "igloo", "website"])
        )
        .frame(width: 500, height: 300)
    }

    #Preview("Long names") {
        RepositoryLoadProgressView(
            progress: RepositoryLoadProgress(
                total: 140,
                completed: 97,
                reading: [
                    "an-extremely-long-monorepo-name-for-the-platform",
                    "another-service-with-a-long-name",
                    "ios-client",
                    "infrastructure-as-code"
                ]
            )
        )
        .frame(width: 500, height: 300)
    }
#endif
