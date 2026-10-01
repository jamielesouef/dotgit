import Foundation

enum RepositorySortUseCase {
    static func sorted(_ repositories: [TrackedRepository], by order: RepositorySortOrder) -> [TrackedRepository] {
        switch order {
        case .name:
            repositories.sorted { lexicographicallyPrecedes($0.name, $1.name) }
        case .path:
            repositories.sorted { lexicographicallyPrecedes(path(of: $0), path(of: $1)) }
        case .status:
            repositories.sorted { first, second in
                guard first.status == second.status else {
                    return rank(first.status) < rank(second.status)
                }

                return lexicographicallyPrecedes(first.name, second.name)
            }
        case .lastSynced:
            repositories.sorted { first, second in
                let firstDate = first.shared.lastSuccessfulSyncDate ?? .distantPast
                let secondDate = second.shared.lastSuccessfulSyncDate ?? .distantPast

                guard firstDate == secondDate else {
                    return firstDate > secondDate
                }

                return lexicographicallyPrecedes(first.name, second.name)
            }
        }
    }

    // MARK: - Helpers

    private static func rank(_ status: RepositoryStatus) -> Int {
        guard let index = RepositoryStatus.allCases.firstIndex(of: status) else {
            return RepositoryStatus.allCases.count
        }

        return index
    }

    private static func path(of repository: TrackedRepository) -> String {
        repository.localPath?.path(percentEncoded: false) ?? repository.shared.preferredRelativePath
    }

    private static func lexicographicallyPrecedes(_ first: String, _ second: String) -> Bool {
        first.localizedCaseInsensitiveCompare(second) == .orderedAscending
    }
}
