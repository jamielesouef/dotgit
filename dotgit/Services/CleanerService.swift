import Foundation

@MainActor
@Observable
final class CleanerService: SingleFlightRefreshing {
    // MARK: - State

    enum LoadState: Equatable {
        case loading
        case empty
        case loaded([CleanupItem])
    }

    var loadState: LoadState {
        switch (isLoading, items.isEmpty) {
        case (true, true):
            .loading
        case (false, true):
            .empty
        case (_, false):
            .loaded(items)
        }
    }

    private(set) var runtimes: [SimulatorRuntime] = []
    private(set) var derivedData: [DerivedDataEntry] = []
    private(set) var selectedIdentifiers: Set<String> = []
    private(set) var lastOutcomes: [CleanupOutcome] = []
    private(set) var isRemoving = false

    var categories: Set<CleanupCategory> {
        Set(settings.localSettings.defaultCleanupCategories)
    }

    var items: [CleanupItem] {
        CleanupPlanUseCase.items(runtimes: runtimes, derivedData: derivedData, categories: categories)
    }

    var plan: CleanupPlan {
        CleanupPlanUseCase.plan(
            runtimes: runtimes,
            derivedData: derivedData,
            categories: categories,
            selectedIdentifiers: selectedIdentifiers
        )
    }

    // MARK: - SingleFlightRefreshing

    var refreshTask: Task<Void, Never>?

    // MARK: - Private

    private let runtimeProvider: any SimulatorRuntimeProviding
    private let derivedDataProvider: any DerivedDataProviding
    private let repositories: RepositoriesService
    private let settings: SettingsService

    private var isLoading = false
    private var hasStarted = false

    // MARK: - Init

    init(
        runtimeProvider: any SimulatorRuntimeProviding,
        derivedDataProvider: any DerivedDataProviding,
        repositories: RepositoriesService,
        settings: SettingsService
    ) {
        self.runtimeProvider = runtimeProvider
        self.derivedDataProvider = derivedDataProvider
        self.repositories = repositories
        self.settings = settings
    }

    // MARK: - Intent

    func start() async {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        await refresh()
    }

    func toggle(_ item: CleanupItem) {
        guard item.isDeletable else {
            return
        }
        guard selectedIdentifiers.insert(item.id).inserted == false else {
            return
        }

        selectedIdentifiers.remove(item.id)
    }

    func setSelected(_ isSelected: Bool, for item: CleanupItem) {
        guard item.isDeletable else {
            return
        }
        guard selectedIdentifiers.contains(item.id) != isSelected else {
            return
        }

        if isSelected {
            selectedIdentifiers.insert(item.id)
        } else {
            selectedIdentifiers.remove(item.id)
        }
    }

    func isSelected(_ item: CleanupItem) -> Bool {
        selectedIdentifiers.contains(item.id)
    }

    func setCategory(_ category: CleanupCategory, isEnabled: Bool) {
        settings.updateLocalSettings { local in
            var categories = Set(local.defaultCleanupCategories)

            if isEnabled {
                categories.insert(category)
            } else {
                categories.remove(category)
            }

            local.defaultCleanupCategories = CleanupCategory.allCases.filter { categories.contains($0) }
        }
    }

    func applyCategory(_ category: CleanupCategory, isEnabled: Bool) async {
        guard categories.contains(category) != isEnabled else {
            return
        }

        setCategory(category, isEnabled: isEnabled)
        await refresh()
    }

    func removeSelected() async {
        let selected = plan.items

        guard selected.isEmpty == false else {
            return
        }

        isRemoving = true
        var outcomes: [CleanupOutcome] = []

        for item in selected {
            await outcomes.append(remove(item))
        }

        lastOutcomes = outcomes
        selectedIdentifiers = []
        isRemoving = false
        await refresh()
    }

    func clearOutcomes() {
        lastOutcomes = []
    }

    // MARK: - SingleFlightRefreshing

    func performRefresh() async {
        isLoading = true

        let local = settings.localSettings
        let projectRoots = repositories.repositories.compactMap(\.localPath)
        let customPaths = local.additionalDerivedDataPaths.map { URL(filePath: $0) }

        let fetchedRuntimes = categories.contains(.simulatorRuntimes) ? await runtimeProvider.runtimes() : []
        let fetchedDerivedData = categories.contains(.derivedData)
            ? await derivedDataProvider.entries(
                includesDefaultLocation: local.includesDefaultDerivedData,
                projectRoots: projectRoots,
                customPaths: customPaths
            )
            : []

        guard Task.isCancelled == false else {
            return
        }

        runtimes = fetchedRuntimes
        derivedData = fetchedDerivedData
        selectedIdentifiers = selectedIdentifiers.intersection(Set(items.map(\.id)))
        isLoading = false
    }

    // MARK: - Helpers

    private func remove(_ item: CleanupItem) async -> CleanupOutcome {
        guard item.isDeletable else {
            return CleanupOutcome(item: item, failureMessage: CleanupError.protectedLocation(item.detail).message)
        }

        do {
            switch item.target {
            case let .simulatorRuntime(identifier):
                try await runtimeProvider.delete(identifier: identifier)
            case let .derivedData(url):
                try await derivedDataProvider.remove(at: url)
            }
        } catch {
            return CleanupOutcome(item: item, failureMessage: error.message)
        }

        return CleanupOutcome(item: item, failureMessage: nil)
    }
}
