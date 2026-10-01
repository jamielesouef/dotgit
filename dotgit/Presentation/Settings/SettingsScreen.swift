import SwiftUI

struct SettingsScreen: View {
    // MARK: - View

    var body: some View {
        Form {
            TodaySettingsSection()
            RepositorySettingsSection()
            DiscoverySettingsSection()
            GitHubAccountSettingsSection()
            ResumeSettingsSection()
            PortableWorkspaceSettingsSection()
            ReadinessSettingsSection()
            CleanerSettingsSection()
            MenuBarSettingsSection()
            RepositoryMaintenanceSection()
        }
        .formStyle(.grouped)
    }
}

#if DEBUG
    #Preview("Populated") {
        SettingsScreen()
            .environment(\.settingsService, PreviewGraph.populated.settings)
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.workspaceService, PreviewGraph.populated.workspace)
            .environment(\.cleanerService, PreviewGraph.populated.cleaner)
            .environment(\.accountsService, PreviewGraph.populated.accounts)
            .frame(width: 720, height: 700)
    }

    #Preview("Empty workspace") {
        SettingsScreen()
            .environment(\.settingsService, PreviewGraph.empty.settings)
            .environment(\.repositoriesService, PreviewGraph.empty.repositories)
            .environment(\.workspaceService, PreviewGraph.empty.workspace)
            .environment(\.cleanerService, PreviewGraph.empty.cleaner)
            .environment(\.accountsService, PreviewGraph.empty.accounts)
            .frame(width: 720, height: 700)
    }
#endif
