import Foundation

@MainActor
final class AppGraph {
    // MARK: - Services

    let settings: SettingsService
    let onboarding: OnboardingService
    let repositories: RepositoriesService
    let sync: SyncService
    let resume: ResumeService
    let workspace: WorkspaceService
    let accounts: GitHubAccountsService
    let cleaner: CleanerService
    let filePanel: any FilePanelPresenting

    // MARK: - Init

    init(
        settings: SettingsService,
        onboarding: OnboardingService,
        repositories: RepositoriesService,
        sync: SyncService,
        resume: ResumeService,
        workspace: WorkspaceService,
        accounts: GitHubAccountsService,
        cleaner: CleanerService,
        filePanel: any FilePanelPresenting
    ) {
        self.settings = settings
        self.onboarding = onboarding
        self.repositories = repositories
        self.sync = sync
        self.resume = resume
        self.workspace = workspace
        self.accounts = accounts
        self.cleaner = cleaner
        self.filePanel = filePanel
    }
}
