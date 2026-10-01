import Foundation

enum UntrackedSelectionUseCase {
    // MARK: - Defaults

    static func startingSelections(
        for checkouts: [TrackedRepository],
        existing: [String: Set<String>],
        includesByDefault: Bool
    ) -> [String: Set<String>] {
        guard includesByDefault else {
            return existing
        }

        var selections = existing

        for checkout in checkouts {
            selections[checkout.id] = Set(checkout.snapshot?.workingTree.untrackedPaths ?? [])
        }

        return selections
    }

    // MARK: - Select all

    static func selectingAll(
        _ isSelected: Bool,
        in steps: [SyncPlanStep],
        existing: [String: Set<String>]
    ) -> [String: Set<String>] {
        var selections = existing

        for step in steps where step.selectableUntrackedPaths.isEmpty == false {
            selections[step.identifier] = isSelected ? Set(step.selectableUntrackedPaths) : []
        }

        return selections
    }

    static func selectAllTitle(isEverythingSelected: Bool) -> String {
        isEverythingSelected
            ? String(localized: "Deselect all untracked files")
            : String(localized: "Select all untracked files")
    }

    static func stepSelectAllTitle(isEverythingSelected: Bool) -> String {
        isEverythingSelected ? String(localized: "Select none") : String(localized: "Select all")
    }
}
