import SwiftUI

struct MenuBarLabel: View {
    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories
    @Environment(\.settingsService) private var settings

    // MARK: - View

    var body: some View {
        HStack(spacing: AppSpacing.xsmall) {
            Image(systemName: status.level.symbolName)

            if let badge {
                Text(badge)
            }
        }
        .accessibilityLabel(status.summary)
    }

    // MARK: - Helpers

    private var status: MenuBarStatus {
        MenuBarStatusUseCase.status(for: repositories.todaySummary)
    }

    private var badge: String? {
        MenuBarStatusUseCase.badgeText(for: status, showsCount: settings.preferences.menuBarShowsLocalOnlyCount)
    }
}

#if DEBUG
    #Preview("With a count") {
        MenuBarLabel()
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.settingsService, PreviewGraph.populated.settings)
            .padding()
    }

    #Preview("All clear") {
        MenuBarLabel()
            .environment(\.repositoriesService, PreviewGraph.empty.repositories)
            .environment(\.settingsService, PreviewGraph.empty.settings)
            .padding()
    }
#endif
