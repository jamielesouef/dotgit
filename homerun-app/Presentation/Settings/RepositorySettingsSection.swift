import SwiftUI

struct RepositorySettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var requiresSyncConfirmation = AppPreferences.default.requiresSyncConfirmation
    @State private var includesUntrackedFiles = AppPreferences.default.includesUntrackedFilesByDefault
    @State private var asksBeforeCreatingUpstream = AppPreferences.default.asksBeforeCreatingUpstream
    @State private var wipCommitPrefix = AppPreferences.default.wipCommitPrefix
    @State private var appendsTimestamp = AppPreferences.default.appendsTimestampToWIPCommit
    @State private var sortOrder = AppPreferences.default.repositorySortOrder

    // MARK: - View

    var body: some View {
        Section(String(localized: "Repositories")) {
            Toggle(String(localized: "Ask me to confirm before syncing"), isOn: $requiresSyncConfirmation)

            Toggle(String(localized: "Include untracked files by default"), isOn: $includesUntrackedFiles)

            Text(
                String(
                    localized: "Every untracked file starts ticked in the sync review. Without confirmation they are committed straight away."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Toggle(String(localized: "Ask before creating a branch on the remote"), isOn: $asksBeforeCreatingUpstream)

            Text(
                String(
                    localized: "Every unpushed branch goes up when you sync. With this off, new branches are created on the remote without asking."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            LabeledContent(String(localized: "WIP commit prefix")) {
                TextField(AppPreferences.fallbackWIPCommitPrefix, text: $wipCommitPrefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }

            Text(String(localized: "A repository can override this. When neither is set, homerun uses WIP."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(String(localized: "Append the time to WIP commit messages"), isOn: $appendsTimestamp)

            Picker(String(localized: "Default sort order"), selection: $sortOrder) {
                ForEach(RepositorySortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
        }
        .onChange(of: settings.preferences.requiresSyncConfirmation, initial: true) {
            requiresSyncConfirmation = settings.preferences.requiresSyncConfirmation
        }
        .onChange(of: requiresSyncConfirmation) {
            settings.updatePreferences { $0.requiresSyncConfirmation = requiresSyncConfirmation }
        }
        .onChange(of: settings.preferences.includesUntrackedFilesByDefault, initial: true) {
            includesUntrackedFiles = settings.preferences.includesUntrackedFilesByDefault
        }
        .onChange(of: includesUntrackedFiles) {
            settings.updatePreferences { $0.includesUntrackedFilesByDefault = includesUntrackedFiles }
        }
        .onChange(of: settings.preferences.asksBeforeCreatingUpstream, initial: true) {
            asksBeforeCreatingUpstream = settings.preferences.asksBeforeCreatingUpstream
        }
        .onChange(of: asksBeforeCreatingUpstream) {
            settings.updatePreferences { $0.asksBeforeCreatingUpstream = asksBeforeCreatingUpstream }
        }
        .onChange(of: settings.preferences.wipCommitPrefix, initial: true) {
            wipCommitPrefix = settings.preferences.wipCommitPrefix
        }
        .onChange(of: wipCommitPrefix) {
            settings.updatePreferences { $0.wipCommitPrefix = wipCommitPrefix }
        }
        .onChange(of: settings.preferences.appendsTimestampToWIPCommit, initial: true) {
            appendsTimestamp = settings.preferences.appendsTimestampToWIPCommit
        }
        .onChange(of: appendsTimestamp) {
            settings.updatePreferences { $0.appendsTimestampToWIPCommit = appendsTimestamp }
        }
        .onChange(of: settings.preferences.repositorySortOrder, initial: true) {
            sortOrder = settings.preferences.repositorySortOrder
        }
        .onChange(of: sortOrder) {
            settings.updatePreferences { $0.repositorySortOrder = sortOrder }
        }
    }
}

#if DEBUG
    #Preview("Repository settings") {
        Form {
            RepositorySettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .frame(width: 560, height: 360)
    }
#endif
