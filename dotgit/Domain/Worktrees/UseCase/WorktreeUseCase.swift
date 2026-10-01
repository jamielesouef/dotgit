import Foundation

enum WorktreeUseCase {
    // MARK: - Identity

    static func identifier(forWorktreeAt path: URL, in repositoryIdentifier: String) -> String {
        "\(repositoryIdentifier)#worktree:\(normalisedPath(path))"
    }

    static func linkedWorktrees(_ listed: [GitWorktree]) -> [GitWorktree] {
        listed.filter { worktree in
            worktree.isMain == false && worktree.isBare == false && worktree.isPrunable == false
        }
    }

    static func mainCheckout(for url: URL, in listed: [GitWorktree]) -> URL? {
        guard let main = listed.first(where: \.isMain), main.isBare == false else {
            return nil
        }
        guard normalisedPath(main.path) != normalisedPath(url) else {
            return nil
        }

        return main.path
    }

    // MARK: - Linking

    static func linking(_ main: TrackedRepository, to worktrees: [TrackedRepository]) -> TrackedRepository {
        let worktreeBranches = Set(worktrees.compactMap { $0.worktree?.branch })

        let linkedWorktrees = worktrees.map { worktree in
            worktree.replacingSnapshot(
                owningOnlyItsOwnBranch(worktree.snapshot),
                worktrees: []
            )
        }

        return main.replacingSnapshot(
            main.snapshot.map { snapshot in
                var snapshot = snapshot
                snapshot.branchesOwnedElsewhere = worktreeBranches
                    .subtracting([snapshot.currentBranch].compactMap(\.self))

                return snapshot
            },
            worktrees: linkedWorktrees
        )
    }

    // MARK: - Selection

    static func checkout(in repository: TrackedRepository, selectedIdentifier: String?) -> TrackedRepository {
        repository.worktrees.first { $0.id == selectedIdentifier } ?? repository
    }

    static func checkoutsToSync(
        in repositories: [TrackedRepository],
        identifiers: Set<String>?,
        includesWorktrees: Bool
    ) -> [TrackedRepository] {
        repositories.flatMap { repository -> [TrackedRepository] in
            guard let identifiers else {
                return includesWorktrees ? repository.allCheckouts : [repository]
            }
            guard identifiers.contains(repository.id) else {
                return repository.worktrees.filter { identifiers.contains($0.id) }
            }
            guard includesWorktrees else {
                return [repository] + repository.worktrees.filter { identifiers.contains($0.id) }
            }

            return repository.allCheckouts
        }
    }

    static func syncTitle(for checkout: TrackedRepository, in repository: TrackedRepository) -> String {
        switch (checkout.isWorktree, repository.worktrees.isEmpty) {
        case (true, _):
            String(localized: "Sync this worktree")
        case (false, true):
            String(localized: "Sync")
        case (false, false):
            String(localized: "Sync main checkout only")
        }
    }

    // MARK: - Helpers

    private static func owningOnlyItsOwnBranch(_ snapshot: GitRepositorySnapshot?) -> GitRepositorySnapshot? {
        snapshot.map { snapshot in
            var snapshot = snapshot
            snapshot.branchesOwnedElsewhere = Set(snapshot.branches.map(\.name))
                .subtracting([snapshot.currentBranch].compactMap(\.self))

            return snapshot
        }
    }

    private static func normalisedPath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)

        guard path.count > 1, path.hasSuffix("/") else {
            return path
        }

        return String(path.dropLast())
    }
}
