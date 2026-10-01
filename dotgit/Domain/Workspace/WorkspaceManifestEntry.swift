import Foundation

struct WorkspaceManifestEntry: Equatable, Codable, Identifiable {
    let identifier: String
    var name: String
    var remoteURL: String?
    var preferredRelativePath: String
    var allowsMainBranchSync: Bool
    var allowsMasterBranchSync: Bool
    var wipCommitPrefixOverride: String?
    var omitsTimestampFromWIPCommit: Bool?
    var preferredGitHubAccount: String?
    var setupInstructionsPath: String?
    var requiredEnvironmentVariableNames: [String]
    var expectedConfigurationTemplates: [String]

    var id: String {
        identifier
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case remoteURL = "remote_url"
        case preferredRelativePath = "preferred_relative_path"
        case allowsMainBranchSync = "allows_main_branch_sync"
        case allowsMasterBranchSync = "allows_master_branch_sync"
        case wipCommitPrefixOverride = "wip_commit_prefix_override"
        case omitsTimestampFromWIPCommit = "omits_timestamp_from_wip_commit"
        case preferredGitHubAccount = "preferred_github_account"
        case setupInstructionsPath = "setup_instructions_path"
        case requiredEnvironmentVariableNames = "required_environment_variable_names"
        case expectedConfigurationTemplates = "expected_configuration_templates"
    }

    init(_ repository: WorkspaceRepository) {
        identifier = repository.identifier
        name = repository.name
        remoteURL = repository.remoteURL
        preferredRelativePath = repository.preferredRelativePath.isEmpty ? repository.name : repository
            .preferredRelativePath
        allowsMainBranchSync = repository.allowsMainBranchSync
        allowsMasterBranchSync = repository.allowsMasterBranchSync
        wipCommitPrefixOverride = repository.wipCommitPrefixOverride
        omitsTimestampFromWIPCommit = repository.omitsTimestampFromWIPCommit
        preferredGitHubAccount = repository.preferredGitHubAccount
        setupInstructionsPath = repository.setupInstructionsPath
        requiredEnvironmentVariableNames = repository.requiredEnvironmentVariableNames
        expectedConfigurationTemplates = repository.expectedConfigurationTemplates
    }

    func merged(into existing: WorkspaceRepository?, addedDate: Date) -> WorkspaceRepository {
        var repository = existing ?? WorkspaceRepository(identifier: identifier, name: name, addedDate: addedDate)

        repository.name = name
        repository.remoteURL = remoteURL
        repository.preferredRelativePath = preferredRelativePath
        repository.allowsMainBranchSync = allowsMainBranchSync
        repository.allowsMasterBranchSync = allowsMasterBranchSync
        repository.wipCommitPrefixOverride = wipCommitPrefixOverride
        repository.omitsTimestampFromWIPCommit = omitsTimestampFromWIPCommit ?? repository.omitsTimestampFromWIPCommit
        repository.preferredGitHubAccount = preferredGitHubAccount
        repository.setupInstructionsPath = setupInstructionsPath
        repository.requiredEnvironmentVariableNames = requiredEnvironmentVariableNames
        repository.expectedConfigurationTemplates = expectedConfigurationTemplates

        return repository
    }
}
