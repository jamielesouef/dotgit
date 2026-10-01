import SwiftUI
import UniformTypeIdentifiers

struct CleanerSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings
    @Environment(\.cleanerService) private var cleaner
    @Environment(\.filePanel) private var filePanel

    // MARK: - State

    @State private var includesDefaultDerivedData = LocalSettings.default.includesDefaultDerivedData

    // MARK: - View

    var body: some View {
        Section(String(localized: "Cleaner")) {
            Toggle(String(localized: "Include the default Derived Data location"), isOn: $includesDefaultDerivedData)

            ForEach(CleanupCategory.allCases) { category in
                MirroredToggle(
                    title: String(localized: "Show \(category.title) in the review"),
                    value: cleaner.categories.contains(category)
                ) { isEnabled in
                    cleaner.setCategory(category, isEnabled: isEnabled)
                }
            }

            LabeledContent(String(localized: "Extra Derived Data paths")) {
                Button(String(localized: "Add…"), action: addDerivedDataPath)
            }

            ForEach(settings.localSettings.additionalDerivedDataPaths, id: \.self) { path in
                HStack {
                    Text(path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(String(localized: "Remove"), systemImage: "minus.circle") {
                        settings.updateLocalSettings { local in
                            local.additionalDerivedDataPaths.removeAll { $0 == path }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        }
        .onChange(of: settings.localSettings.includesDefaultDerivedData, initial: true) {
            includesDefaultDerivedData = settings.localSettings.includesDefaultDerivedData
        }
        .onChange(of: includesDefaultDerivedData) {
            settings.updateLocalSettings { $0.includesDefaultDerivedData = includesDefaultDerivedData }
        }
    }

    private func addDerivedDataPath() {
        guard let url = filePanel.chooseFolder(
            message: String(localized: "Choose a Derived Data folder to include")
        ) else {
            return
        }

        settings.updateLocalSettings { local in
            let path = url.path(percentEncoded: false)

            guard local.additionalDerivedDataPaths.contains(path) == false else {
                return
            }

            local.additionalDerivedDataPaths.append(path)
        }
    }
}

#if DEBUG
    #Preview("Cleaner settings") {
        Form {
            CleanerSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .environment(\.cleanerService, PreviewGraph.populated.cleaner)
        .frame(width: 620, height: 360)
    }
#endif
