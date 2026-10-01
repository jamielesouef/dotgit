import Foundation
import SwiftData

@Model
final class SharedRepositoryRecord {
    var identifier: String = ""
    var name: String = ""
    var remoteURL: String?
    var preferredRelativePath: String = ""
    var allowsMainBranchSync: Bool = false
    var allowsMasterBranchSync: Bool = false
    var wipCommitPrefixOverride: String?
    var omitsTimestampFromWIPCommit: Bool = false
    var preferredGitHubAccount: String?
    var setupInstructionsPath: String?
    var requiredEnvironmentVariableNames: [String] = []
    var expectedConfigurationTemplates: [String] = []
    var handoffBranch: String?
    var handoffCommit: String?
    var handoffRecordedAt: Date?
    var lastSuccessfulSyncDate: Date?
    var addedDate: Date = Date.distantPast

    init(identifier: String = "") {
        self.identifier = identifier
    }

    // MARK: - Domain

    var domainValue: WorkspaceRepository {
        WorkspaceRepository(
            identifier: identifier,
            name: name,
            remoteURL: remoteURL,
            preferredRelativePath: preferredRelativePath,
            allowsMainBranchSync: allowsMainBranchSync,
            allowsMasterBranchSync: allowsMasterBranchSync,
            wipCommitPrefixOverride: wipCommitPrefixOverride,
            omitsTimestampFromWIPCommit: omitsTimestampFromWIPCommit,
            preferredGitHubAccount: preferredGitHubAccount,
            setupInstructionsPath: setupInstructionsPath,
            requiredEnvironmentVariableNames: requiredEnvironmentVariableNames,
            expectedConfigurationTemplates: expectedConfigurationTemplates,
            handoff: handoff,
            lastSuccessfulSyncDate: lastSuccessfulSyncDate,
            addedDate: addedDate
        )
    }

    func apply(_ repository: WorkspaceRepository) {
        identifier = repository.identifier
        name = repository.name
        remoteURL = repository.remoteURL
        preferredRelativePath = repository.preferredRelativePath
        allowsMainBranchSync = repository.allowsMainBranchSync
        allowsMasterBranchSync = repository.allowsMasterBranchSync
        wipCommitPrefixOverride = repository.wipCommitPrefixOverride
        omitsTimestampFromWIPCommit = repository.omitsTimestampFromWIPCommit
        preferredGitHubAccount = repository.preferredGitHubAccount
        setupInstructionsPath = repository.setupInstructionsPath
        requiredEnvironmentVariableNames = repository.requiredEnvironmentVariableNames
        expectedConfigurationTemplates = repository.expectedConfigurationTemplates
        handoffBranch = repository.handoff?.branch
        handoffCommit = repository.handoff?.commit
        handoffRecordedAt = repository.handoff?.recordedAt
        lastSuccessfulSyncDate = repository.lastSuccessfulSyncDate
        addedDate = repository.addedDate
    }

    // MARK: - Helpers

    private var handoff: RepositoryHandoff? {
        guard let handoffBranch, let handoffCommit, let handoffRecordedAt else {
            return nil
        }

        return RepositoryHandoff(branch: handoffBranch, commit: handoffCommit, recordedAt: handoffRecordedAt)
    }
}
