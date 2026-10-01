import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppKitFilePanelPresenter: FilePanelPresenting {
    // MARK: - FilePanelPresenting

    func chooseFolder(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = String(localized: "Choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        return url(from: panel)
    }

    func chooseFile(message: String, contentTypes: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = String(localized: "Choose")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = contentTypes

        return url(from: panel)
    }

    func chooseSaveLocation(message: String, suggestedName: String, contentType: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.message = message
        panel.prompt = String(localized: "Save")
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    // MARK: - Helpers

    private func url(from panel: NSOpenPanel) -> URL? {
        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls.first
    }
}
