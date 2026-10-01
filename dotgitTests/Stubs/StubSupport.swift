import Foundation
@testable import dotgit

struct StubClock: Clocking {
    let fixedNow: Date
    let timeZone: TimeZone

    init(
        now: Date = Date(timeIntervalSince1970: 1_758_600_000),
        timeZone: TimeZone = TimeZone(identifier: "UTC") ?? .gmt
    ) {
        fixedNow = now
        self.timeZone = timeZone
    }

    func now() -> Date {
        fixedNow
    }
}

actor StubProjectOpener: ProjectOpening {
    private(set) var opened: [(url: URL, application: URL?)] = []
    var succeeds = true

    func open(_ url: URL, withApplicationAt applicationURL: URL?) async -> Bool {
        opened.append((url, applicationURL))

        return succeeds
    }
}

actor StubRepositoryDiscovery: RepositoryDiscovering {
    var results: [DiscoveredRepository] = []
    private(set) var ignoredFolderNames: Set<String> = []
    private(set) var scanCount = 0

    init(results: [DiscoveredRepository] = []) {
        self.results = results
    }

    func discoverRepositories(
        in root: URL,
        ignoredFolderNames: Set<String>,
        maximumDepth: Int
    ) async -> [DiscoveredRepository] {
        scanCount += 1
        self.ignoredFolderNames = ignoredFolderNames

        return results
    }
}

actor StubReadinessChecker: ReadinessChecking {
    var reports: [String: ReadinessReport] = [:]
    private(set) var inputs: [ReadinessCheckInput] = []

    func setReport(_ report: ReadinessReport, for identifier: String) {
        reports[identifier] = report
    }

    func evaluate(_ input: ReadinessCheckInput) async -> ReadinessReport {
        inputs.append(input)

        return reports[input.repository.identifier]
            ?? ReadinessReport(identifier: input.repository.identifier, currentBranchPushed: true, issues: [])
    }
}

actor StubSyncEngine: RepositorySyncPerforming {
    var results: [String: RepositorySyncOutcome.Result] = [:]
    private(set) var requests: [RepositorySyncRequest] = []

    func setResult(_ result: RepositorySyncOutcome.Result, for identifier: String) {
        results[identifier] = result
    }

    func sync(_ request: RepositorySyncRequest) async -> RepositorySyncReport {
        requests.append(request)

        return RepositorySyncReport(
            identifier: request.identifier,
            branch: request.branch,
            result: results[request.identifier] ?? .succeeded(commit: "newhead", branch: request.branch),
            fallback: nil,
            committed: request.willCommit
        )
    }
}

actor StubWorkspaceManifestStore: WorkspaceManifestStoring {
    var manifests: [String: WorkspaceManifest] = [:]
    var loadError: WorkspaceManifestError?
    var saveError: WorkspaceManifestError?
    private(set) var saved: [(manifest: WorkspaceManifest, url: URL)] = []

    func setManifest(_ manifest: WorkspaceManifest, at url: URL) {
        manifests[url.path(percentEncoded: false)] = manifest
    }

    func setLoadError(_ error: WorkspaceManifestError?) {
        loadError = error
    }

    func load(from url: URL) async throws(WorkspaceManifestError) -> WorkspaceManifest {
        if let loadError {
            throw loadError
        }

        guard let manifest = manifests[url.path(percentEncoded: false)] else {
            throw .fileUnreadable(url.path(percentEncoded: false))
        }

        return manifest
    }

    func save(_ manifest: WorkspaceManifest, to url: URL) async throws(WorkspaceManifestError) {
        if let saveError {
            throw saveError
        }

        saved.append((manifest, url))
        manifests[url.path(percentEncoded: false)] = manifest
    }
}

actor StubSimulatorRuntimeProvider: SimulatorRuntimeProviding {
    var storedRuntimes: [SimulatorRuntime] = []
    var deleteFailures: Set<String> = []
    private(set) var deleted: [String] = []

    func setRuntimes(_ runtimes: [SimulatorRuntime]) {
        storedRuntimes = runtimes
    }

    func setDeleteFailures(_ failures: Set<String>) {
        deleteFailures = failures
    }

    func runtimes() async -> [SimulatorRuntime] {
        storedRuntimes
    }

    func delete(identifier: String) async throws(CleanupError) {
        deleted.append(identifier)

        guard deleteFailures.contains(identifier) == false else {
            throw .removalFailed(identifier)
        }

        storedRuntimes.removeAll { $0.identifier == identifier }
    }
}

actor StubDerivedDataProvider: DerivedDataProviding {
    var storedEntries: [DerivedDataEntry] = []
    private(set) var removed: [URL] = []
    private(set) var lastProjectRoots: [URL] = []
    private(set) var lastIncludesDefault = false

    func setEntries(_ entries: [DerivedDataEntry]) {
        storedEntries = entries
    }

    func entries(
        includesDefaultLocation: Bool,
        projectRoots: [URL],
        customPaths: [URL]
    ) async -> [DerivedDataEntry] {
        lastIncludesDefault = includesDefaultLocation
        lastProjectRoots = projectRoots

        return storedEntries
    }

    func remove(at url: URL) async throws(CleanupError) {
        removed.append(url)
        storedEntries.removeAll { $0.url == url }
    }
}
