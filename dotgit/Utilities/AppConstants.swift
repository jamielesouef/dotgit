import Foundation

enum AppConstants {
    static let cloudKitContainerInfoKey = "HRCloudKitContainerIdentifier"
    static let localSettingsSuiteName = "mobi.jamie.dotgit"

    static let toolSearchDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin"
    ]

    static let discoveryMaximumDepth = 6
    static let recentCommitLimit = 10
    static let concurrentRepositoryReads = 4
}
