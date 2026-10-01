import Foundation

struct GitHubAccount: Equatable, Identifiable, Hashable {
    let login: String
    let host: String
    let isActive: Bool

    var id: String {
        "\(host)/\(login)"
    }
}
