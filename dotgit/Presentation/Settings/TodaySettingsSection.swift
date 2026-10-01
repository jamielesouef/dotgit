import SwiftUI

struct TodaySettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var defaultFilter = AppPreferences.default.defaultRepositoryStatusFilter
    @State private var showsCleanRepositories = AppPreferences.default.showsCleanRepositories

    // MARK: - View

    var body: some View {
        Section(String(localized: "Today")) {
            Picker(String(localized: "Default status filter"), selection: $defaultFilter) {
                ForEach(RepositoryStatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }

            Toggle(
                String(localized: "Show repositories that are clean and fully synced"),
                isOn: $showsCleanRepositories
            )
        }
        .onChange(of: settings.preferences.defaultRepositoryStatusFilter, initial: true) {
            defaultFilter = settings.preferences.defaultRepositoryStatusFilter
        }
        .onChange(of: defaultFilter) {
            settings.updatePreferences { $0.defaultRepositoryStatusFilter = defaultFilter }
        }
        .onChange(of: settings.preferences.showsCleanRepositories, initial: true) {
            showsCleanRepositories = settings.preferences.showsCleanRepositories
        }
        .onChange(of: showsCleanRepositories) {
            settings.updatePreferences { $0.showsCleanRepositories = showsCleanRepositories }
        }
    }
}

#if DEBUG
    #Preview("Today settings") {
        Form {
            TodaySettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .frame(width: 560, height: 200)
    }
#endif
