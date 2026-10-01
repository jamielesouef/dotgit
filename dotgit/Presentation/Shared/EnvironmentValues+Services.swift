import SwiftUI

private let defaultAppGraph = MainActor.assumeIsolated {
    AppDependencies.shared
}

extension EnvironmentValues {
    @Entry var settingsService: SettingsService = defaultAppGraph.settings
    @Entry var onboardingService: OnboardingService = defaultAppGraph.onboarding
    @Entry var repositoriesService: RepositoriesService = defaultAppGraph.repositories
    @Entry var syncService: SyncService = defaultAppGraph.sync
    @Entry var resumeService: ResumeService = defaultAppGraph.resume
    @Entry var workspaceService: WorkspaceService = defaultAppGraph.workspace
    @Entry var accountsService: GitHubAccountsService = defaultAppGraph.accounts
    @Entry var cleanerService: CleanerService = defaultAppGraph.cleaner
    @Entry var filePanel: any FilePanelPresenting = defaultAppGraph.filePanel
}
