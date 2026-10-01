import Foundation

struct ResumeStep: Equatable, Identifiable {
    let identifier: String
    let name: String
    let action: ResumeAction
    let handoff: RepositoryHandoff?
    var isSelected: Bool

    var id: String {
        identifier
    }
}
