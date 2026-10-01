import Foundation
import UniformTypeIdentifiers

@MainActor
protocol FilePanelPresenting: AnyObject, Sendable {
    func chooseFolder(message: String) -> URL?
    func chooseFile(message: String, contentTypes: [UTType]) -> URL?
    func chooseSaveLocation(message: String, suggestedName: String, contentType: UTType) -> URL?
}
