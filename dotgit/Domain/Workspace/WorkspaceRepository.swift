import Foundation

struct WorkspaceRepository: Equatable, Identifiable, Codable {
    let identifier: String
    var name: String
    var remoteURL: String?
    var preferredRelativePath: String
    var allowsMainBranchSync: Bool
    var allowsMasterBranchSync: Bool
    var wipCommitPrefixOverride: String?
    var omitsTimestampFromWIPCommit: Bool
    var preferredGitHubAccount: String?
    var setupInstructionsPath: String?
    var requiredEnvironmentVariableNames: [String]
    var expectedConfigurationTemplates: [String]
    var handoff: RepositoryHandoff?
    var lastSuccessfulSyncDate: Date?
    var addedDate: Date

    var id: String {
        identifier
    }

    init(
        identifier: String,
        name: String,
        remoteURL: String? = nil,
        preferredRelativePath: String = "",
        allowsMainBranchSync: Bool = false,
        allowsMasterBranchSync: Bool = false,
        wipCommitPrefixOverride: String? = nil,
        omitsTimestampFromWIPCommit: Bool = false,
        preferredGitHubAccount: String? = nil,
        setupInstructionsPath: String? = nil,
        requiredEnvironmentVariableNames: [String] = [],
        expectedConfigurationTemplates: [String] = [],
        handoff: RepositoryHandoff? = nil,
        lastSuccessfulSyncDate: Date? = nil,
        addedDate: Date = .distantPast
    ) {
        self.identifier = identifier
        self.name = name
        self.remoteURL = remoteURL
        self.preferredRelativePath = preferredRelativePath
        self.allowsMainBranchSync = allowsMainBranchSync
        self.allowsMasterBranchSync = allowsMasterBranchSync
        self.wipCommitPrefixOverride = wipCommitPrefixOverride
        self.omitsTimestampFromWIPCommit = omitsTimestampFromWIPCommit
        self.preferredGitHubAccount = preferredGitHubAccount
        self.setupInstructionsPath = setupInstructionsPath
        self.requiredEnvironmentVariableNames = requiredEnvironmentVariableNames
        self.expectedConfigurationTemplates = expectedConfigurationTemplates
        self.handoff = handoff
        self.lastSuccessfulSyncDate = lastSuccessfulSyncDate
        self.addedDate = addedDate
    }
}
