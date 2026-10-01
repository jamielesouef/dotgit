import SwiftUI
import UniformTypeIdentifiers

struct PortableWorkspaceSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings
    @Environment(\.workspaceService) private var workspace
    @Environment(\.repositoriesService) private var repositories
    @Environment(\.filePanel) private var filePanel

    // MARK: - View

    var body: some View {
        Section(String(localized: "Portable workspace")) {
            LabeledContent(String(localized: "This Mac's workspace root")) {
                HStack {
                    Text(settings.localSettings.workspaceRootPath ?? String(localized: "Not set"))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(String(localized: "Choose…"), action: chooseWorkspaceRoot)
                }
            }

            LabeledContent(String(localized: "Manifest")) {
                HStack {
                    Text(settings.localSettings.manifestPath ?? String(localized: "None selected"))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(String(localized: "Load…"), action: loadManifest)

                    Button(String(localized: "Write…"), action: writeManifest)
                }
            }

            preview
            relativePaths
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        switch workspace.loadState {
        case .idle:
            Text(String(localized: "Load a manifest to preview what this Mac would clone."))
                .font(.caption)
                .foregroundStyle(.secondary)
        case .loading:
            ProgressView()
                .controlSize(.small)
        case let .error(error):
            Label(error.message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        case let .loaded(manifest, plan):
            loadedPreview(manifest, plan: plan)
        }
    }

    private func loadedPreview(_ manifest: WorkspaceManifest, plan: WorkspacePlan) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(
                String(
                    localized: "\(manifest.name), version \(manifest.version): \(plan.cloneCount) to clone, \(plan.updateCount) already here."
                )
            )
            .font(.caption)

            ForEach(plan.entries) { entry in
                Text("\(entry.name) — \(entry.action.summary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button(String(localized: "Apply to the shared workspace")) {
                Task {
                    await workspace.applyManifest()
                }
            }

            if let message = workspace.lastAppliedMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Relative paths

    @ViewBuilder
    private var relativePaths: some View {
        if repositories.repositories.isEmpty == false {
            DisclosureGroup(String(localized: "Preferred relative paths")) {
                ForEach(repositories.repositories) { repository in
                    LabeledContent(repository.name) {
                        MirroredTextField(repository.name, value: repository.shared.preferredRelativePath) { path in
                            workspace.setPreferredRelativePath(path, for: repository.id)
                        }
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func chooseWorkspaceRoot() {
        guard let url = filePanel.chooseFolder(
            message: String(localized: "Choose where this Mac clones repositories")
        ) else {
            return
        }

        workspace.setWorkspaceRoot(url)
    }

    private func loadManifest() {
        guard let url = filePanel.chooseFile(
            message: String(localized: "Choose a workspace manifest"),
            contentTypes: [.json]
        ) else {
            return
        }

        Task {
            await workspace.loadManifest(at: url)
        }
    }

    private func writeManifest() {
        guard let url = filePanel.chooseSaveLocation(
            message: String(localized: "Write the shared workspace to a manifest"),
            suggestedName: "dotgit-workspace.json",
            contentType: .json
        ) else {
            return
        }

        Task {
            await workspace.exportManifest(named: url.deletingPathExtension().lastPathComponent, to: url)
        }
    }
}

#if DEBUG
    #Preview("Portable workspace") {
        Form {
            PortableWorkspaceSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .environment(\.workspaceService, PreviewGraph.populated.workspace)
        .environment(\.repositoriesService, PreviewGraph.populated.repositories)
        .frame(width: 620, height: 480)
    }

    #Preview("Nothing configured") {
        Form {
            PortableWorkspaceSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.empty.settings)
        .environment(\.workspaceService, PreviewGraph.empty.workspace)
        .environment(\.repositoriesService, PreviewGraph.empty.repositories)
        .frame(width: 620, height: 480)
    }
#endif
