import Foundation

struct GitSubmoduleChange: Equatable, Identifiable {
    enum Kind: Equatable {
        case uninitialised
        case commitDiffers
        case mergeConflict
    }

    let path: String
    let kind: Kind

    var id: String {
        path
    }
}
