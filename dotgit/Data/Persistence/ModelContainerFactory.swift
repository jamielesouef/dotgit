import Foundation
import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([SharedRepositoryRecord.self, SharedPreferencesRecord.self])

    static func make(
        inMemory: Bool,
        cloudKitContainerIdentifier: String?
    ) throws(PersistenceError) -> ModelContainer {
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            switch cloudKitContainerIdentifier {
            case let identifier? where inMemory == false:
                .private(identifier)
            case .some,
                 .none:
                .none
            }

        do {
            return try ModelContainer(for: schema, configurations: [configuration(inMemory, cloudKitDatabase)])
        } catch {
            return try makeLocalFallback(inMemory: inMemory, underlying: error)
        }
    }

    // MARK: - Helpers

    /// The app is not sandboxed, so SwiftData's default location is the shared
    /// `~/Library/Application Support/default.store`. Other unsandboxed processes
    /// (icloudmailagent, for one) migrate that file to their own model, dropping ours.
    static var storeURL: URL {
        let folder = URL.applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "dotgit")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        return folder.appending(path: "dotgit.store")
    }

    private static func configuration(
        _ inMemory: Bool,
        _ cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        guard inMemory == false else {
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }

        return ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloudKitDatabase)
    }

    private static func makeLocalFallback(
        inMemory: Bool,
        underlying: any Error
    ) throws(PersistenceError) -> ModelContainer {
        AppLog.error("Falling back to a local store: \(underlying.localizedDescription)")

        do {
            return try ModelContainer(for: schema, configurations: [configuration(inMemory, .none)])
        } catch {
            throw .containerUnavailable(error.localizedDescription)
        }
    }
}
