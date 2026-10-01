import Foundation

protocol SimulatorRuntimeProviding: Sendable {
    func runtimes() async -> [SimulatorRuntime]
    func delete(identifier: String) async throws(CleanupError)
}
