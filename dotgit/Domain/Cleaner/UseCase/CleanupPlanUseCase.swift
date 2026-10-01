import Foundation

enum CleanupPlanUseCase {
    static func plan(
        runtimes: [SimulatorRuntime],
        derivedData: [DerivedDataEntry],
        categories: Set<CleanupCategory>,
        selectedIdentifiers: Set<String>
    ) -> CleanupPlan {
        CleanupPlan(items: items(runtimes: runtimes, derivedData: derivedData, categories: categories)
            .filter { selectedIdentifiers.contains($0.id) })
    }

    static func items(
        runtimes: [SimulatorRuntime],
        derivedData: [DerivedDataEntry],
        categories: Set<CleanupCategory>
    ) -> [CleanupItem] {
        var items: [CleanupItem] = []

        if categories.contains(.simulatorRuntimes) {
            items.append(contentsOf: runtimes.map(item))
        }

        if categories.contains(.derivedData) {
            items.append(contentsOf: derivedData.map(item))
        }

        return items
    }

    // MARK: - Helpers

    private static func item(_ runtime: SimulatorRuntime) -> CleanupItem {
        CleanupItem(
            title: runtime.displayName,
            detail: runtime.path ?? runtime.identifier,
            sizeBytes: runtime.sizeBytes,
            category: .simulatorRuntimes,
            target: .simulatorRuntime(runtime.identifier),
            isDeletable: CleanupSafetyUseCase.isDeletable(runtime)
        )
    }

    private static func item(_ entry: DerivedDataEntry) -> CleanupItem {
        CleanupItem(
            title: entry.name,
            detail: entry.url.path(percentEncoded: false),
            sizeBytes: entry.sizeBytes,
            category: .derivedData,
            target: .derivedData(entry.url),
            isDeletable: CleanupSafetyUseCase.isDeletable(entry)
        )
    }
}
