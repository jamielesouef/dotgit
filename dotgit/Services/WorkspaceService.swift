import Foundation

@MainActor
@Observable
final class WorkspaceService {
    // MARK: - State

    enum LoadState: Equatable {
        case idle
        case loading
        case error(WorkspaceManifestError)
        case loaded(WorkspaceManifest, WorkspacePlan)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var lastAppliedMessage: String?

    var loadedManifest: WorkspaceManifest? {
        guard case let .loaded(manifest, _) = loadState else {
            return nil
        }

        return manifest
    }

    var plan: WorkspacePlan? {
        guard case let .loaded(_, plan) = loadState else {
            return nil
        }

        return plan
    }

    // MARK: - Private

    private let manifestStore: any WorkspaceManifestStoring
    private let sharedStore: any SharedWorkspaceStoring
    private let repositories: RepositoriesService
    private let settings: SettingsService
    private let clock: any Clocking

    // MARK: - Init

    init(
        manifestStore: any WorkspaceManifestStoring,
        sharedStore: any SharedWorkspaceStoring,
        repositories: RepositoriesService,
        settings: SettingsService,
        clock: any Clocking
    ) {
        self.manifestStore = manifestStore
        self.sharedStore = sharedStore
        self.repositories = repositories
        self.settings = settings
        self.clock = clock
    }

    // MARK: - Intent

    func loadManifest(at url: URL) async {
        loadState = .loading
        settings.updateLocalSettings { $0.manifestPath = url.path(percentEncoded: false) }

        do {
            let manifest = try await manifestStore.load(from: url)

            guard Task.isCancelled == false else {
                return
            }

            loadState = .loaded(manifest, preview(manifest))
        } catch {
            loadState = .error(error)
        }
    }

    func reloadSelectedManifest() async {
        guard let path = settings.localSettings.manifestPath else {
            loadState = .idle
            return
        }

        await loadManifest(at: URL(filePath: path))
    }

    func setWorkspaceRoot(_ url: URL) {
        settings.updateLocalSettings { $0.workspaceRootPath = url.path(percentEncoded: false) }
        refreshPreview()
    }

    func setPreferredRelativePath(_ path: String, for identifier: String) {
        guard var repository = try? sharedStore.repository(identifier: identifier) else {
            return
        }

        repository.preferredRelativePath = path
        repositories.update(repository)
        refreshPreview()
    }

    func applyManifest() async {
        guard case let .loaded(manifest, _) = loadState else {
            return
        }

        let existing = (try? sharedStore.loadRepositories()) ?? []
        var applied = 0

        for entry in manifest.repositories {
            let merged = entry.merged(
                into: existing.first { $0.identifier == entry.identifier },
                addedDate: clock.now()
            )

            do {
                try sharedStore.upsert(merged)
                applied += 1
            } catch {
                AppLog.error("Could not apply \(entry.identifier): \(String(describing: error))")
            }
        }

        lastAppliedMessage = String(localized: "Applied \(applied) repository(s) from \(manifest.name).")
        await repositories.refresh()
        refreshPreview()
    }

    func exportManifest(named name: String, to url: URL) async {
        let repositories = (try? sharedStore.loadRepositories()) ?? []
        let manifest = WorkspaceManifest.make(name: name, repositories: repositories)

        do {
            try await manifestStore.save(manifest, to: url)
            settings.updateLocalSettings { $0.manifestPath = url.path(percentEncoded: false) }
            loadState = .loaded(manifest, preview(manifest))
            lastAppliedMessage =
                String(localized: "Wrote \(manifest.repositories.count) repository(s) to \(url.lastPathComponent).")
        } catch {
            loadState = .error(error)
        }
    }

    func clearMessage() {
        lastAppliedMessage = nil
    }

    // MARK: - Helpers

    private func refreshPreview() {
        guard case let .loaded(manifest, _) = loadState else {
            return
        }

        loadState = .loaded(manifest, preview(manifest))
    }

    private func preview(_ manifest: WorkspaceManifest) -> WorkspacePlan {
        WorkspacePlanUseCase.plan(
            manifest: manifest,
            workspaceRoot: settings.localSettings.workspaceRoot,
            localPaths: settings.localSettings.repositoryPaths
        )
    }
}
