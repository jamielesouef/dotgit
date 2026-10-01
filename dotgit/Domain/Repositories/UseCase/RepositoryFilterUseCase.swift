import Foundation

enum RepositoryFilterUseCase {
    static func matches(_ repository: TrackedRepository, filter: RepositoryStatusFilter) -> Bool {
        repository.allCheckouts.contains { checkout in
            checkoutMatches(checkout, filter: filter)
        }
    }

    static func checkoutMatches(_ repository: TrackedRepository, filter: RepositoryStatusFilter) -> Bool {
        switch filter {
        case .all:
            true
        case .dirty:
            repository.snapshot?.isDirty == true
        case .clean:
            repository.status == .clean
        case .ahead:
            (repository.snapshot?.aheadCount ?? 0) > 0
        case .behind:
            (repository.snapshot?.behindCount ?? 0) > 0
        case .failed:
            repository.status == .failed || repository.status == .unreadable
        }
    }

    static func apply(
        to repositories: [TrackedRepository],
        filter: RepositoryStatusFilter,
        showsCleanRepositories: Bool,
        searchText: String
    ) -> [TrackedRepository] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return repositories.filter { repository in
            guard matches(repository, filter: filter) else {
                return false
            }
            guard showsCleanRepositories || repository.allCheckouts.contains(where: { $0.status != .clean }) else {
                return false
            }
            guard trimmed.isEmpty == false else {
                return true
            }

            return repository.allCheckouts.contains { checkout in
                checkout.checkoutName.lowercased().contains(trimmed)
                    || checkout.localPath?.path(percentEncoded: false).lowercased().contains(trimmed) == true
            }
        }
    }
}
