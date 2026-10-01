import SwiftUI

struct RepositoryStatusBadge: View {
    // MARK: - Inputs

    let status: RepositoryStatus

    // MARK: - View

    var body: some View {
        content
            .font(.caption)
            .foregroundStyle(tint)
            .accessibilityLabel(status.title)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch status {
        case .loading:
            HStack(spacing: AppSpacing.xsmall) {
                SnakeProgressView()

                Text(status.title)
            }
        case .notCloned,
             .failed,
             .diverged,
             .dirty,
             .ahead,
             .behind,
             .clean,
             .unreadable:
            Label(status.title, systemImage: status.symbolName)
                .labelStyle(.titleAndIcon)
        }
    }

    // MARK: - Helpers

    private var tint: Color {
        switch status {
        case .clean:
            .green
        case .ahead,
             .dirty:
            .orange
        case .behind:
            .blue
        case .diverged,
             .failed,
             .unreadable:
            .red
        case .notCloned,
             .loading:
            .secondary
        }
    }
}

#if DEBUG
    #Preview("Every status") {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ForEach(RepositoryStatus.allCases, id: \.rawValue) { status in
                RepositoryStatusBadge(status: status)
            }
        }
        .padding(AppSpacing.regular)
    }
#endif
