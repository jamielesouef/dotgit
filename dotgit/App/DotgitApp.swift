import SwiftUI

@main
struct DotgitApp: App {
    // MARK: - Environment

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var showsMenuBarItem = LocalSettings.default.showsMenuBarItem

    // MARK: - Scene

    var body: some Scene {
        Window(String(localized: "dotgit"), id: AppWindow.main.rawValue) {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)

        MenuBarExtra(isInserted: $showsMenuBarItem) {
            MenuBarContentView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
        .onChange(of: settings.localSettings.showsMenuBarItem, initial: true) {
            showsMenuBarItem = settings.localSettings.showsMenuBarItem
        }
        .onChange(of: showsMenuBarItem) {
            settings.updateLocalSettings { $0.showsMenuBarItem = showsMenuBarItem }
        }
    }
}
