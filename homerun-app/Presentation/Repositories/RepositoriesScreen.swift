import SwiftUI

struct RepositoriesScreen: View {
    // MARK: - Constants

    private enum Constants {
        static let listMinimumWidth: CGFloat = 280
        static let listIdealWidth: CGFloat = 320
        static let listMaximumWidth: CGFloat = 380
    }

    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories
    @Environment(\.syncService) private var sync
    @Environment(\.filePanel) private var filePanel

    // MARK: - State

    @State private var selection: Set<String> = []
    @State private var discovered: [DiscoveredRepository] = []
    @State private var isShowingDiscovered = false
    @State private var pendingRemoval: RepositoryRemoval?
    @State private var filter: RepositoryStatusFilter = .all
    @State private var sortOrder: RepositorySortOrder = .name
    @State private var searchText = ""
    @State private var scanPromptFolder: URL?
    @State private var isShowingScanPrompt = false

    // MARK: - View

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                list

                Divider()

                bottomBar
            }
            .frame(
                minWidth: Constants.listMinimumWidth,
                idealWidth: Constants.listIdealWidth,
                maxWidth: Constants.listMaximumWidth
            )

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await repositories.start()
        }
        .toolbar {
            ToolbarItemGroup {
                Picker(String(localized: "Filter"), selection: $filter) {
                    ForEach(RepositoryStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker(String(localized: "Sort"), selection: $sortOrder) {
                    ForEach(RepositorySortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.menu)

                Button(String(localized: "Add repository"), systemImage: "plus", action: addRepository)

                Button(String(localized: "Scan a folder"), systemImage: "magnifyingglass", action: scanFolder)

                Button(String(localized: "Refresh"), systemImage: "arrow.triangle.2.circlepath") {
                    Task {
                        await repositories.refresh()
                    }
                }

                Button(String(localized: "Sync selected"), systemImage: "icloud.and.arrow.up") {
                    Task {
                        await sync.review(identifiers: selection.isEmpty ? nil : selection)
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .syncFlow()
        .sheet(isPresented: $isShowingDiscovered) {
            DiscoveredRepositoriesSheet(discovered: discovered) { chosen in
                discovered = []

                Task {
                    await repositories.add(chosen)
                }
            } cancel: {
                discovered = []
            }
        }
        .confirmationDialog(
            String(localized: "Not a git repository"),
            isPresented: $isShowingScanPrompt,
            titleVisibility: .visible,
            presenting: scanPromptFolder
        ) { folder in
            Button(String(localized: "Search for repositories")) {
                Task {
                    discovered = await repositories.scanFolder(folder)
                }
            }

            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: { folder in
            Text(
                String(
                    localized: "\(folder.lastPathComponent) is not a git repository. Search inside it for repositories to track?"
                )
            )
        }
        .alert(item: $pendingRemoval) { removal in
            Alert(
                title: Text(removal.title),
                message: Text(removal.explanation),
                primaryButton: .destructive(Text(String(localized: "Remove"))) {
                    perform(removal)
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: repositories.filter, initial: true) {
            filter = repositories.filter
        }
        .onChange(of: filter) {
            repositories.filter = filter
        }
        .onChange(of: repositories.sortOrder, initial: true) {
            sortOrder = repositories.sortOrder
        }
        .onChange(of: sortOrder) {
            repositories.sortOrder = sortOrder
        }
        .onChange(of: repositories.searchText, initial: true) {
            searchText = repositories.searchText
        }
        .onChange(of: searchText) {
            repositories.searchText = searchText
        }
        .onChange(of: discovered) {
            isShowingDiscovered = discovered.isEmpty == false
        }
        .onChange(of: isShowingDiscovered) {
            guard isShowingDiscovered == false else {
                return
            }

            discovered = []
        }
        .onChange(of: repositories.folderAwaitingScanDecision, initial: true) {
            scanPromptFolder = repositories.folderAwaitingScanDecision
            isShowingScanPrompt = scanPromptFolder != nil
        }
        .onChange(of: isShowingScanPrompt) {
            guard isShowingScanPrompt == false, let scanPromptFolder else {
                return
            }

            repositories.dismissScanDecision(for: scanPromptFolder)
        }
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        switch repositories.loadState {
        case let .loading(progress):
            RepositoryLoadProgressView(progress: progress)
        case let .error(error):
            EmptyStateView(
                symbolName: "exclamationmark.icloud",
                title: String(localized: "The shared workspace could not be read"),
                message: String(describing: error),
                actionTitle: String(localized: "Try again"),
                action: { Task { await repositories.refresh() } }
            )
        case .empty:
            EmptyStateView(
                symbolName: "folder.badge.plus",
                title: String(localized: "No repositories tracked"),
                message: String(localized: "Choose a repository folder, scan a parent folder, or drag one in."),
                actionTitle: String(localized: "Add repository"),
                action: addRepository
            )
        case .loaded:
            loadedList
        }
    }

    private var loadedList: some View {
        let visible = repositories.visibleRepositories

        return List(visible, selection: $selection) { repository in
            RepositoryRowView(repository: repository)
        }
        .contextMenu(forSelectionType: String.self) { identifiers in
            menu(for: identifiers)
        }
        .onDeleteCommand {
            requestRemoval(of: selection, scope: .shared)
        }
        .animation(.snappy, value: visible.map(\.id))
    }

    @ViewBuilder
    private func menu(for identifiers: Set<String>) -> some View {
        if identifiers.isEmpty == false {
            Button(String(localized: "Sync")) {
                Task {
                    await sync.review(identifiers: identifiers)
                }
            }

            Divider()
        }

        Button(String(localized: "Select all"), action: selectAll)

        if identifiers.isEmpty == false {
            Divider()

            Button(String(localized: "Remove this Mac's path"), role: .destructive) {
                requestRemoval(of: identifiers, scope: .local)
            }

            Button(String(localized: "Remove from the shared workspace"), role: .destructive) {
                requestRemoval(of: identifiers, scope: .shared)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Button(String(localized: "Add repository"), systemImage: "plus", action: addRepository)
                .buttonStyle(.borderless)

            if let message = repositories.lastMaintenanceMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.small)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if selection.count > 1 {
            EmptyStateView(
                symbolName: "checklist",
                title: String(localized: "\(selection.count) repositories selected"),
                message: String(
                    localized: "Right-click to sync or remove them, or press Delete to remove them from the shared workspace."
                )
            )
        } else if let identifier = selection.first, let repository = repositories.repository(identifier: identifier) {
            RepositoryDetailView(repository: repository)
        } else {
            EmptyStateView(
                symbolName: "sidebar.right",
                title: String(localized: "Nothing selected"),
                message: String(localized: "Pick a repository to see its changes, branches and recent activity.")
            )
        }
    }

    // MARK: - Helpers

    private func addRepository() {
        guard let url = filePanel.chooseFolder(message: String(localized: "Choose a git repository to track")) else {
            return
        }

        Task {
            _ = await repositories.addRepository(at: url)
        }
    }

    private func scanFolder() {
        guard let url = filePanel.chooseFolder(
            message: String(localized: "Choose a folder to scan for git repositories")
        ) else {
            return
        }

        Task {
            discovered = await repositories.scanFolder(url)
        }
    }

    private func selectAll() {
        selection = Set(repositories.visibleRepositories.map(\.id))
    }

    private func requestRemoval(of identifiers: Set<String>, scope: ConfigurationScope) {
        guard identifiers.isEmpty == false else {
            return
        }

        pendingRemoval = RepositoryRemoval(identifiers: identifiers, scope: scope)
    }

    private func perform(_ removal: RepositoryRemoval) {
        selection.subtract(removal.identifiers)

        switch removal.scope {
        case .local:
            repositories.removeLocalPathMappings(identifiers: removal.identifiers)
        case .shared:
            repositories.removeFromSharedWorkspace(identifiers: removal.identifiers)
        }
    }
}

#if DEBUG
    #Preview("Populated") {
        RepositoriesScreen()
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .environment(\.syncService, PreviewGraph.populated.sync)
            .environment(\.accountsService, PreviewGraph.populated.accounts)
            .frame(width: 960, height: 620)
    }

    #Preview("Empty") {
        RepositoriesScreen()
            .environment(\.repositoriesService, PreviewGraph.empty.repositories)
            .environment(\.syncService, PreviewGraph.empty.sync)
            .environment(\.accountsService, PreviewGraph.empty.accounts)
            .frame(width: 960, height: 620)
    }

    #Preview("Long names") {
        RepositoriesScreen()
            .environment(\.repositoriesService, PreviewGraph.longNames.repositories)
            .environment(\.syncService, PreviewGraph.longNames.sync)
            .environment(\.accountsService, PreviewGraph.longNames.accounts)
            .frame(width: 960, height: 620)
    }
#endif
