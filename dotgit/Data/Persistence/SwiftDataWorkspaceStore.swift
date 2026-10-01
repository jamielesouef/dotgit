import Foundation
import SwiftData

@MainActor
final class SwiftDataWorkspaceStore: SharedWorkspaceStoring {
    // MARK: - Private

    private let context: ModelContext

    // MARK: - Init

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - SharedWorkspaceStoring

    func loadRepositories() throws(PersistenceError) -> [WorkspaceRepository] {
        try records().map(\.domainValue)
    }

    func upsert(_ repository: WorkspaceRepository) throws(PersistenceError) {
        let existing = try records().first { $0.identifier == repository.identifier }
        let record = existing ?? SharedRepositoryRecord(identifier: repository.identifier)

        record.apply(repository)

        guard existing == nil else {
            try commit()
            return
        }

        context.insert(record)
        try commit()
    }

    func remove(identifier: String) throws(PersistenceError) {
        let matches = try records().filter { $0.identifier == identifier }

        guard matches.isEmpty == false else {
            throw .recordMissing(identifier)
        }

        for record in matches {
            context.delete(record)
        }

        try commit()
    }

    func removeDuplicates() throws(PersistenceError) -> [String] {
        var seen: Set<String> = []
        var removed: [String] = []

        for record in try records() {
            guard seen.insert(record.identifier).inserted == false else {
                continue
            }

            removed.append(record.identifier)
            context.delete(record)
        }

        try commit()

        return removed
    }

    func removeAllRepositories() throws(PersistenceError) {
        for record in try records() {
            context.delete(record)
        }

        try commit()
    }

    func loadPreferences() throws(PersistenceError) -> AppPreferences {
        try preferencesRecord().domainValue
    }

    func save(_ preferences: AppPreferences) throws(PersistenceError) {
        try preferencesRecord().apply(preferences)
        try commit()
    }

    // MARK: - Helpers

    private func records() throws(PersistenceError) -> [SharedRepositoryRecord] {
        let descriptor = FetchDescriptor<SharedRepositoryRecord>(
            sortBy: [SortDescriptor(\.addedDate), SortDescriptor(\.name)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            throw .fetchFailed(error.localizedDescription)
        }
    }

    private func preferencesRecord() throws(PersistenceError) -> SharedPreferencesRecord {
        let existing: [SharedPreferencesRecord]

        do {
            existing = try context.fetch(FetchDescriptor<SharedPreferencesRecord>())
        } catch {
            throw .fetchFailed(error.localizedDescription)
        }

        guard let first = existing.first else {
            let record = SharedPreferencesRecord()
            context.insert(record)
            try commit()
            return record
        }

        return first
    }

    private func commit() throws(PersistenceError) {
        do {
            try context.save()
        } catch {
            throw .saveFailed(error.localizedDescription)
        }
    }
}
