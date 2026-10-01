import SwiftUI

struct RepositoryMaintenanceSection: View {
    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories

    // MARK: - State

    @State private var pendingScope: ConfigurationScope?

    // MARK: - View

    var body: some View {
        Section(String(localized: "Repository maintenance")) {
            Button(String(localized: "Remove stale paths on this Mac")) {
                repositories.removeStaleLocalPathMappings()
            }

            Button(String(localized: "Remove duplicate entries")) {
                repositories.removeDuplicateEntries()
            }

            ForEach(ConfigurationScope.allCases) { scope in
                Button(String(localized: "Clear tracked repositories — \(scope.title)"), role: .destructive) {
                    pendingScope = scope
                }
            }

            if let message = repositories.lastMaintenanceMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alert(item: $pendingScope) { scope in
            Alert(
                title: Text(String(localized: "Clear tracked repositories?")),
                message: Text(scope.explanation),
                primaryButton: .destructive(Text(String(localized: "Clear"))) {
                    repositories.clearTrackedConfiguration(scope: scope)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

#if DEBUG
    #Preview("Maintenance") {
        Form {
            RepositoryMaintenanceSection()
        }
        .formStyle(.grouped)
        .environment(\.repositoriesService, PreviewGraph.populated.repositories)
        .frame(width: 560, height: 280)
    }
#endif
