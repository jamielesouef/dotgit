import SwiftUI

struct MenuBarSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var showsMenuBarItem = LocalSettings.default.showsMenuBarItem
    @State private var showsLocalOnlyCount = AppPreferences.default.menuBarShowsLocalOnlyCount
    @State private var keepsRunningOnClose = LocalSettings.default.keepsRunningInMenuBarOnClose

    // MARK: - View

    var body: some View {
        Section(String(localized: "Menu bar")) {
            Toggle(String(localized: "Show the menu bar item on this Mac"), isOn: $showsMenuBarItem)

            Toggle(String(localized: "Show a count of repositories with work only here"), isOn: $showsLocalOnlyCount)
                .disabled(showsMenuBarItem == false)

            Toggle(String(localized: "Keep dotgit running when the window closes"), isOn: $keepsRunningOnClose)
        }
        .onChange(of: settings.localSettings.showsMenuBarItem, initial: true) {
            showsMenuBarItem = settings.localSettings.showsMenuBarItem
        }
        .onChange(of: showsMenuBarItem) {
            settings.updateLocalSettings { $0.showsMenuBarItem = showsMenuBarItem }
        }
        .onChange(of: settings.preferences.menuBarShowsLocalOnlyCount, initial: true) {
            showsLocalOnlyCount = settings.preferences.menuBarShowsLocalOnlyCount
        }
        .onChange(of: showsLocalOnlyCount) {
            settings.updatePreferences { $0.menuBarShowsLocalOnlyCount = showsLocalOnlyCount }
        }
        .onChange(of: settings.localSettings.keepsRunningInMenuBarOnClose, initial: true) {
            keepsRunningOnClose = settings.localSettings.keepsRunningInMenuBarOnClose
        }
        .onChange(of: keepsRunningOnClose) {
            settings.updateLocalSettings { $0.keepsRunningInMenuBarOnClose = keepsRunningOnClose }
        }
    }
}

#if DEBUG
    #Preview("Menu bar settings") {
        Form {
            MenuBarSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .frame(width: 560, height: 200)
    }
#endif
