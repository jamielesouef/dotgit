import Foundation

struct SimulatorRuntime: Equatable, Identifiable, Hashable {
    let identifier: String
    let name: String
    let version: String
    let build: String
    let sizeBytes: Int64
    let isDeletable: Bool
    let path: String?

    var id: String {
        identifier
    }

    var displayName: String {
        "\(name) (\(build))"
    }
}
